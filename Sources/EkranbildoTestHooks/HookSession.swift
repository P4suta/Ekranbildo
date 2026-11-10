#if EKRANBILDO_TESTHOOKS
    import Foundation
    import EkranbildoContracts
    import EkranbildoCore
    import EkranbildoEditor
    import EkranbildoObservability

    public final class HookSession: @unchecked Sendable {
        private let lock = NSLock()
        private var document: Document
        private var state: EditorState
        private var ticks: ManualTickSource
        private var trace: TraceLog<ManualTickSource>
        private let interactor: EditorInteractor

        public init(scene: Scene, measurer: any TextMeasuring) {
            document = Document(scene: scene, measurer: measurer)
            state = EditorState(scene: scene)
            ticks = ManualTickSource()
            trace = TraceLog(ticks: ManualTickSource())
            interactor = EditorInteractor(measurer: measurer)
        }

        public var router: HookRouter {
            HookRouter(handlers: [
                HookRouter.Named(name: "scene.dump", handle: { _ in try self.sceneDump() }),
                HookRouter.Named(name: "input.replay", handle: { try self.replay($0) }),
                HookRouter.Named(name: "clock.read", handle: { _ in self.clockRead() }),
                HookRouter.Named(name: "clock.advance", handle: { try self.clockAdvance($0) }),
                HookRouter.Named(name: "trace.export", handle: { _ in self.traceExport() }),
            ])
        }

        private func sceneDump() throws -> String {
            lock.lock()
            defer { lock.unlock() }
            record("scene.dump")
            return try Self.encoded(document.scene)
        }

        private func replay(_ payload: String) throws -> String {
            let events: [InputEvent]
            do {
                events = try JSONDecoder().decode([InputEvent].self, from: Data(payload.utf8))
            } catch {
                throw HookError(detail: "could not read the events: \(error)")
            }

            lock.lock()
            defer { lock.unlock() }
            record("input.replay", .of("events", .int(Int64(events.count))))
            for event in events {
                apply(event)
            }
            return "\(events.count)"
        }

        private func apply(_ event: InputEvent) {
            switch event.handledBy {
            case .history(.back):
                document.undo()
            case .history(.forward):
                document.redo()
            case .theEditor:
                let outcome = interactor.handle(event, in: state)
                state = outcome.state
                if outcome.effects.contains(.checkpoint) {
                    document.checkpoint()
                }
                document.apply(outcome.commands)
            }
            state.scene = document.scene
        }

        private func clockRead() -> String {
            lock.lock()
            defer { lock.unlock() }
            return "\(ticks.next.nanoseconds)"
        }

        private func clockAdvance(_ payload: String) throws -> String {
            struct Step: Decodable { let nanoseconds: Int64 }
            let step: Step
            do {
                step = try JSONDecoder().decode(Step.self, from: Data(payload.utf8))
            } catch {
                throw HookError(detail: "expected {\"nanoseconds\": <number>}: \(error)")
            }
            guard step.nanoseconds >= 0 else {
                throw HookError(detail: "a clock does not go backwards")
            }

            lock.lock()
            defer { lock.unlock() }
            record("clock.advance", .of("nanoseconds", .int(step.nanoseconds)))
            ticks.advance(by: TickInterval(nanoseconds: step.nanoseconds))
            return "\(ticks.next.nanoseconds)"
        }

        private func traceExport() -> String {
            lock.lock()
            defer { lock.unlock() }
            return trace.canonicalText
        }

        private func record(_ name: String, _ attributes: TraceAttributes.Entry...) {
            trace.event(name, attributes: attributes)
        }

        private static func encoded(_ scene: Scene) throws -> String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
            guard let text = String(bytes: try encoder.encode(scene), encoding: .utf8) else {
                throw HookError(detail: "the scene did not encode as text")
            }
            return text
        }
    }

    extension HookRouter {
        public var names: [String] { handlerNames }
    }
#endif
