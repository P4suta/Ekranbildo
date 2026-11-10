import Foundation


public enum Command {
    public struct Failure: Error, CustomStringConvertible {
        public let description: String
    }

    public static func run(_ tool: String, _ arguments: [String], in directory: URL) throws
        -> Outcome
    {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.currentDirectoryURL = directory

        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors

        do {
            try process.run()
        } catch {
            throw Failure(description: "could not start \(tool): \(error)")
        }

        let collected = Collector()
        let group = DispatchGroup()
        for (handle, isError) in [(output.fileHandleForReading, false), (errors.fileHandleForReading, true)] {
            DispatchQueue.global().async(group: group) {
                let data = handle.readDataToEndOfFile()
                collected.add(String(decoding: data, as: UTF8.self), isError: isError)
            }
        }
        group.wait()
        process.waitUntilExit()

        return Outcome(status: process.terminationStatus, output: collected.text)
    }

    private final class Collector: @unchecked Sendable {
        private let lock = NSLock()
        private var standard = ""
        private var errors = ""

        func add(_ text: String, isError: Bool) {
            lock.lock()
            defer { lock.unlock() }
            if isError { errors += text } else { standard += text }
        }

        var text: String {
            lock.lock()
            defer { lock.unlock() }
            return standard + errors
        }
    }
}

extension Outcome {
    public func holds(_ text: String) -> Bool { output.contains(text) }
}
