import Foundation


public enum Fuzzing {
    public static let image = "swift:6.2"

    public static let corpus = "Fixtures/fuzz-corpus"

    public static let buildCommand =
        "swift build -c release -Xswiftc -sanitize=fuzzer,address "
        + "-Xswiftc -DEKRANBILDO_FUZZ --product EkranbildoFuzz"

    public static func linkCommand(binaryPath: String) -> String {
        "swiftc -sanitize=fuzzer,address -I \"$BIN/Modules\" -I \"$BIN\" -L \"$BIN\" "
            + "-emit-executable -o \(binaryPath) "
            + "-Xlinker --whole-archive \"$BIN/libEkranbildoFuzz.a\" -Xlinker --no-whole-archive"
    }

    public static func script(runs: Int?, seconds: Int?) -> String {
        let binary = "/tmp/ekranbildo-fuzz"
        let bound =
            seconds.map { "-max_total_time=\($0)" }
            ?? "-runs=\(runs ?? Defaults.runs)"
        return """
            set -e
            cd /work
            \(buildCommand) > /tmp/build.log 2>&1 || { tail -20 /tmp/build.log; exit 1; }
            BIN=$(swift build -c release --show-bin-path)
            \(linkCommand(binaryPath: binary)) 2> /tmp/link.log \
                || { tail -20 /tmp/link.log; exit 1; }
            mkdir -p /work/\(corpus)
            \(binary) \(bound) -max_len=512 /work/\(corpus)
            """
    }

    private enum Defaults {
        static let runs = 50_000
    }
}
