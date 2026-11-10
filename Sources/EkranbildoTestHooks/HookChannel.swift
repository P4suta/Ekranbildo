#if EKRANBILDO_TESTHOOKS
    import Foundation

    public struct HookError: Error, Equatable {
        public let detail: String

        public init(detail: String) {
            self.detail = detail
        }
    }

    public struct HookRequest: Hashable, Sendable {
        public let name: String
        public let payload: String

        public init(name: String, payload: String) {
            self.name = name
            self.payload = payload
        }

        public var text: String { Framing.wrap(name, payload) }

        public static func parse(_ text: String) throws -> Self {
            try parse(Array(text.utf8))
        }

        public static func parse(_ bytes: [UInt8]) throws -> Self {
            let message = try Framing.unwrap(bytes)
            return Self(name: message.head, payload: message.payload)
        }
    }

    public struct HookReply: Hashable, Sendable {
        public let worked: Bool
        public let payload: String

        public static func ok(_ payload: String) -> Self {
            Self(worked: true, payload: payload)
        }

        public static func failed(_ detail: String) -> Self {
            Self(worked: false, payload: detail)
        }

        public var text: String { Framing.wrap(worked ? Words.ok : Words.failed, payload) }

        public static func parse(_ text: String) throws -> Self {
            let message = try Framing.unwrap(Array(text.utf8))
            let payload = message.payload
            switch message.head {
            case Words.ok: return .ok(payload)
            case Words.failed: return .failed(payload)
            default:
                throw HookError(
                    detail: "a reply begins with \(Words.ok) or \(Words.failed), not '\(message.head)'")
            }
        }

        private enum Words {
            static let ok = "ok"
            static let failed = "failed"
        }
    }

    public struct HookRouter: Sendable {
        public typealias Handler = @Sendable (String) throws -> String

        public struct Named: Sendable {
            public let name: String
            public let handle: Handler

            public init(name: String, handle: @escaping Handler) {
                self.name = name
                self.handle = handle
            }
        }

        private let handlers: [Named]

        public init(handlers: [Named]) {
            self.handlers = handlers
        }

        public static func checked(handlers: [Named]) throws -> Self {
            for (index, handler) in handlers.enumerated() {
                guard !handlers[..<index].contains(where: { $0.name == handler.name }) else {
                    throw HookError(detail: "two handlers are called '\(handler.name)'")
                }
            }
            return Self(handlers: handlers)
        }

        var handlerNames: [String] { handlers.map(\.name) }

        public func reply(to request: HookRequest) -> HookReply {
            guard let handler = handlers.first(where: { $0.name == request.name }) else {
                return .failed(
                    "no such command '\(request.name)'; there is "
                        + handlers.map(\.name).joined(separator: ", ")
                )
            }
            do {
                return .ok(try handler.handle(request.payload))
            } catch let error as HookError {
                return .failed(error.detail)
            } catch {
                return .failed("\(error)")
            }
        }
    }

    public struct Message: Hashable, Sendable {
        public let head: String
        public let payload: String

        public init(head: String, payload: String) {
            self.head = head
            self.payload = payload
        }
    }

    enum Framing {
        static func wrap(_ head: String, _ payload: String) -> String {
            "\(head) \(payload.utf8.count)\(Format.newline)\(payload)"
        }

        static func unwrap(_ bytes: [UInt8]) throws -> Message {
            guard let newline = bytes.firstIndex(of: Format.newlineByte) else {
                throw HookError(detail: "a message is a name, a length, a newline and that many bytes")
            }
            guard let header = String(bytes: bytes[..<newline], encoding: .utf8) else {
                throw HookError(detail: "the message's name and length are not UTF-8")
            }
            let parts = header.split(separator: Format.space, maxSplits: Format.oneSplit)
            guard parts.count == Format.headerParts else {
                throw HookError(detail: "'\(header)' is not a name and a length")
            }
            guard let length = Int(parts[1]), length >= 0 else {
                throw HookError(detail: "'\(parts[1])' is not a length")
            }

            let start = bytes.index(after: newline)
            guard bytes.count - start >= length else {
                throw HookError(
                    detail: "the message says \(length) bytes and \(bytes.count - start) arrived"
                )
            }
            let body = bytes[start..<(start + length)]
            guard let payload = String(bytes: body, encoding: .utf8) else {
                throw HookError(detail: "the message's payload is not UTF-8")
            }
            return Message(head: String(parts[0]), payload: payload)
        }

        private enum Format {
            static let newline = "\n"
            static let newlineByte = UInt8(ascii: "\n")
            static let space: Character = " "
            static let headerParts = 2
            static let oneSplit = 1
        }
    }
#endif
