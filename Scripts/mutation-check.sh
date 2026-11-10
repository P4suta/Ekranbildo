#!/usr/bin/env bash

set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

MUTATIONS="Scripts/mutations.tsv"
FILTER=""
WORKERS=4

while [ $# -gt 0 ]; do
    case "$1" in
        --filter) FILTER="${2:-}"; shift 2 ;;
        --workers) WORKERS="${2:-}"; shift 2 ;;
        *) echo "unknown argument: $1" >&2; exit 1 ;;
    esac
done

count_occurrences() {
    python3 -c 'import sys, pathlib; print(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8").count(sys.argv[2]))' "$1" "$2"
}

echo "==> Checking every mutation still describes the code"
preflight=0
selected=0
while IFS=$'\t' read -r target search replace description extra; do
    case "$target" in
        ''|'#'*) continue ;;
    esac
    if [ -z "$description" ] || [ -n "$extra" ]; then
        printf '  malformed row (needs exactly 4 tab-separated columns, no newlines): %s\n' \
            "$target" >&2
        preflight=$((preflight + 1))
        continue
    fi
    if [ -z "$search" ] || [ -z "$replace" ] && [ "$replace" != "" ]; then
        printf '  row has nothing to search for: %s\n' "$description" >&2
        preflight=$((preflight + 1))
        continue
    fi
    if [ ! -f "$target" ]; then
        printf '  missing file: %s (%s)\n' "$target" "$description" >&2
        preflight=$((preflight + 1))
        continue
    fi
    occurrences=$(count_occurrences "$target" "$search")
    if [ "$occurrences" != "1" ]; then
        printf '  anchor appears %s times, expected 1: %s\n' "$occurrences" "$description" >&2
        preflight=$((preflight + 1))
    fi
    if [ -z "$FILTER" ] || [[ "$description" == *"$FILTER"* ]]; then
        selected=$((selected + 1))
    fi
done < "$MUTATIONS"

if [ "$preflight" -gt 0 ]; then
    echo "FAILED: $preflight mutation(s) no longer describe the code." >&2
    echo "The code moved and the anchor needs updating." >&2
    exit 1
fi

if [ "$selected" -eq 0 ]; then
    echo "No mutation matches '$FILTER'." >&2
    exit 1
fi

if [ "$selected" -lt "$WORKERS" ]; then
    WORKERS="$selected"
fi

SCRATCH="$(mktemp -d)"
cleanup() {
    rm -rf "$SCRATCH"
}
trap cleanup EXIT INT TERM

awk -F'\t' '/^[^#]/ && NF >= 4 { print $1 }' "$MUTATIONS" | sort -u > "$SCRATCH/targets"
xargs shasum < "$SCRATCH/targets" | awk '{ print $1 }' > "$SCRATCH/baseline"

echo ""
echo "==> Preparing $WORKERS working copies"
for worker in $(seq 1 "$WORKERS"); do
    mkdir -p "$SCRATCH/w$worker"
    rsync -a --exclude '.build' --exclude '.git' ./ "$SCRATCH/w$worker/"
done

awk -F'\t' -v filter="$FILTER" '
    /^[^#]/ && NF >= 4 {
        if (filter == "" || index($4, filter)) { printf "%d\t%s\n", ++n, $0 }
    }
' "$MUTATIONS" > "$SCRATCH/selected.tsv"

run_worker() {
    local worker="$1" directory="$SCRATCH/w$1"
    while IFS=$'\t' read -r index target search replace description; do
        if [ $(( (index - 1) % WORKERS + 1 )) -ne "$worker" ]; then
            continue
        fi

        local backup="$directory/$target.mutation-backup"
        cp "$directory/$target" "$backup"

        if ! python3 -c '
import sys, pathlib
path, search, replace = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
text = path.read_text(encoding="utf-8")
if text.count(search) != 1:
    sys.exit("anchor appears %d times, expected exactly 1" % text.count(search))
path.write_text(text.replace(search, replace), encoding="utf-8")
' "$directory/$target" "$search" "$replace"; then
            printf 'ERROR' > "$SCRATCH/result.$index"
        elif (cd "$directory" && swift test >/dev/null 2>&1); then
            printf 'SURVIVED' > "$SCRATCH/result.$index"
        else
            printf 'killed' > "$SCRATCH/result.$index"
        fi

        mv "$backup" "$directory/$target"
    done < "$SCRATCH/selected.tsv"
}

echo ""
echo "==> Mutating ($selected mutations)"
for worker in $(seq 1 "$WORKERS"); do
    run_worker "$worker" &
done
wait

survived=0
killed=0
unmeasured=0
while IFS=$'\t' read -r index _ _ _ description; do
    outcome="$(cat "$SCRATCH/result.$index" 2>/dev/null || echo NOT_MEASURED)"
    case "$outcome" in
        killed)
            printf '  killed        %s\n' "$description"
            killed=$((killed + 1))
            ;;
        SURVIVED)
            printf '  SURVIVED      %s\n' "$description"
            survived=$((survived + 1))
            ;;
        *)
            printf '  NOT MEASURED  %s\n' "$description"
            unmeasured=$((unmeasured + 1))
            ;;
    esac
done < "$SCRATCH/selected.tsv"

echo ""
for worker in $(seq 1 "$WORKERS"); do
    if ! (cd "$SCRATCH/w$worker" && xargs shasum < "$SCRATCH/targets" | awk '{ print $1 }') \
        | diff -q - "$SCRATCH/baseline" >/dev/null; then
        echo "FAILED: worker $worker did not restore a file it mutated." >&2
        echo "Everything it tested after that point was tested against broken code." >&2
        exit 1
    fi
done

if [ "$unmeasured" -gt 0 ]; then
    echo "mutants killed: $killed, survived: $survived, NOT MEASURED: $unmeasured"
    echo "" >&2
    echo "$unmeasured mutant(s) were never measured: a worker wrote no result for them." >&2
    echo "That is not a survivor and not a kill - it is a run that did not finish," >&2
    echo "and the score above is about fewer mutants than were asked for." >&2
    exit 1
fi

echo "mutants killed: $killed, survived: $survived"
[ "$survived" -eq 0 ]
