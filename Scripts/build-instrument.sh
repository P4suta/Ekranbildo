#!/usr/bin/env bash

set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

SOURCE="Instruments/Ekranbildo.instrpkg"
OUTPUT="${1:-$(mktemp -d)}/Ekranbildo.instrdst"

BUILDER="$(xcode-select -p)/usr/bin/instrumentbuilder"
if [ ! -x "$BUILDER" ]; then
    echo "FAILED: no instrumentbuilder at $BUILDER." >&2
    echo "It comes with Xcode, which this project already needs for swift-testing." >&2
    exit 1
fi

echo "==> Building $SOURCE"

"$BUILDER" -i "$SOURCE" -o "$OUTPUT" 2>&1 | grep -v "DVTInstrumentsFoundation"

if [ ! -d "$OUTPUT" ]; then
    echo "FAILED: the package did not build." >&2
    exit 1
fi

echo "    ok"
