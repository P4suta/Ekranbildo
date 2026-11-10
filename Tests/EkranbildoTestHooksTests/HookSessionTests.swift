#if EKRANBILDO_TESTHOOKS
    import Foundation
    import EkranbildoContracts
    import EkranbildoCore
    import EkranbildoEditor
    import EkranbildoFixtures
    @testable import EkranbildoTestHooks
    import Testing

    @Suite("Hook session")
    struct HookSessionTests {

        private static let scene = Scene(
            canvas: SceneRect(x: 0, y: 0, width: 400, height: 300),
            background: nil,
            annotations: [
                Annotation(
                    id: AnnotationID(1),
                    target: SceneRect(x: 40, y: 180, width: 80, height: 24),
                    label: "First",
                    placement: nil
                )
            ],
            style: .standard
        )

        private func session() -> HookSession {
            HookSession(scene: Self.scene, measurer: TabulatedTextMeasurer.uniform())
        }

        private func ask(_ session: HookSession, _ name: String, _ payload: String = "") -> HookReply {
            session.router.reply(to: HookRequest(name: name, payload: payload))
        }

        @Test("The scene comes back as the document format, not as a description of it")
        func sceneDumpIsTheDocument() throws {
            let reply = ask(session(), "scene.dump")
            #expect(reply.worked)
            let decoded = try JSONDecoder().decode(Scene.self, from: Data(reply.payload.utf8))
            #expect(decoded.annotations.map(\.id) == Self.scene.annotations.map(\.id))
        }

        @Test("Asking twice gives the same bytes")
        func sceneDumpIsStable() {
            let session = session()
            let first = ask(session, "scene.dump").payload
            let second = ask(session, "scene.dump").payload
            #expect(first == second)
        }

        @Test("Replayed events change the scene the next dump returns")
        func replayedEventsChangeTheScene() throws {
            let session = session()
            let events: [InputEvent] = [
                .toolSelected(.annotate),
                .pointerDown(ScenePoint(x: 200, y: 100), Modifiers()),
                .pointerUp(ScenePoint(x: 260, y: 140), Modifiers()),
            ]
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let payload = String(bytes: try encoder.encode(events), encoding: .utf8) ?? ""

            let reply = ask(session, "input.replay", payload)
            #expect(reply.worked)

            let after = try JSONDecoder().decode(
                Scene.self, from: Data(ask(session, "scene.dump").payload.utf8))
            #expect(after.annotations.count == Self.scene.annotations.count + 1)
        }

        @Test("A replay of nothing is allowed and changes nothing")
        func replayingNothingChangesNothing() {
            let session = session()
            let before = ask(session, "scene.dump").payload
            #expect(ask(session, "input.replay", "[]").worked)
            #expect(ask(session, "scene.dump").payload == before)
        }

        @Test("A replay that is not events is refused, and says so")
        func replayingRubbishIsRefused() {
            let reply = ask(session(), "input.replay", "{\"not\": \"events\"}")
            #expect(!reply.worked)
        }

        @Test("Undo goes back to what the scene was")
        func undoGoesBack() throws {
            let session = session()
            let before = ask(session, "scene.dump").payload
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let events: [InputEvent] = [
                .toolSelected(.annotate),
                .pointerDown(ScenePoint(x: 200, y: 100), Modifiers()),
                .pointerUp(ScenePoint(x: 260, y: 140), Modifiers()),
            ]
            let drawn = String(bytes: try encoder.encode(events), encoding: .utf8) ?? ""
            _ = ask(session, "input.replay", drawn)
            #expect(ask(session, "scene.dump").payload != before)

            let undone = String(bytes: try encoder.encode([InputEvent.undo]), encoding: .utf8) ?? ""
            _ = ask(session, "input.replay", undone)
            #expect(ask(session, "scene.dump").payload == before)
        }

        @Test("Undo still goes back when the pointer moved after the change")
        func undoGoesBackAfterAnIdleEvent() throws {
            let session = session()
            let before = ask(session, "scene.dump").payload
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]

            let drawing: [InputEvent] = [
                .toolSelected(.annotate),
                .pointerDown(ScenePoint(x: 200, y: 100), Modifiers()),
                .pointerUp(ScenePoint(x: 260, y: 140), Modifiers()),
                .pointerMoved(ScenePoint(x: 300, y: 200), Modifiers()),
            ]
            let played = String(bytes: try encoder.encode(drawing), encoding: .utf8) ?? ""
            _ = ask(session, "input.replay", played)
            #expect(ask(session, "scene.dump").payload != before)

            let undone = String(bytes: try encoder.encode([InputEvent.undo]), encoding: .utf8) ?? ""
            _ = ask(session, "input.replay", undone)
            #expect(ask(session, "scene.dump").payload == before)
        }

        @Test("The clock moves only when it is told to")
        func clockAdvancesOnRequest() {
            let session = session()
            let before = ask(session, "clock.read").payload
            #expect(ask(session, "clock.advance", "{\"nanoseconds\": 500}").worked)
            let after = ask(session, "clock.read").payload
            #expect(before != after)
            #expect(Int(after) == (Int(before) ?? 0) + 500)
        }

        @Test("A clock told to move by something that is not a number is refused")
        func clockRefusesRubbish() {
            #expect(!ask(session(), "clock.advance", "{\"nanoseconds\": \"soon\"}").worked)
        }

        @Test("A clock cannot be told to go backwards")
        func clockRefusesToGoBack() {
            #expect(!ask(session(), "clock.advance", "{\"nanoseconds\": -1}").worked)
        }

        @Test("The trace holds what the session did")
        func traceHoldsWhatHappened() {
            let session = session()
            _ = ask(session, "scene.dump")
            let trace = ask(session, "trace.export")
            #expect(trace.worked)
            #expect(trace.payload.contains("scene.dump"))
        }

        @Test("Every command answers, including the ones that refuse")
        func everyCommandAnswers() {
            for name in session().router.names {
                #expect(!ask(session(), name, "").text.isEmpty)
            }
        }

        @Test("No two commands share a name")
        func namesAreUnique() {
            let names = session().router.names
            #expect(Set(names).count == names.count)
        }
    }
#endif
