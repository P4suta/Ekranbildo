#if EKRANBILDO_TESTHOOKS
    import Foundation
    import EkranbildoContracts
    import EkranbildoCore
    @testable import EkranbildoTestHooks
    import Testing

    @Suite("Hook framing")
    struct HookFramingTests {

        @Test("A request is its name and the bytes that follow")
        func requestParses() throws {
            let request = try HookRequest.parse("scene.dump 0\n")
            #expect(request.name == "scene.dump")
            #expect(request.payload.isEmpty)
        }

        @Test("A payload is taken by length, not by looking for an end")
        func payloadIsTakenByLength() throws {
            let request = try HookRequest.parse("clock.advance 12\n{\"ms\": 100}\n")
            #expect(request.name == "clock.advance")
            #expect(request.payload == "{\"ms\": 100}\n")
        }

        @Test("A payload may contain anything at all")
        func payloadMayContainAnything() throws {
            let awkward = "{\n  \"a\": \"line\\nbreak\"\n}"
            let request = try HookRequest.parse(
                "input.replay \(awkward.utf8.count)\n\(awkward)")
            #expect(request.payload == awkward)
        }

        @Test("The length is in bytes, not in characters")
        func lengthIsInBytes() throws {
            let japanese = "{\"label\": \"保存ボタン\"}"
            #expect(japanese.count != japanese.utf8.count)
            let request = try HookRequest.parse(
                "input.replay \(japanese.utf8.count)\n\(japanese)")
            #expect(request.payload == japanese)
        }

        @Test("A request says how to write it, so that a client and a server agree")
        func requestRoundTrips() throws {
            let original = HookRequest(name: "scene.dump", payload: "{\"a\": 1}")
            #expect(try HookRequest.parse(original.text) == original)
        }

        @Test("A message with no length is refused")
        func lengthIsRequired() {
            #expect(throws: HookError.self) { try HookRequest.parse("scene.dump\n") }
        }

        @Test("A length that is not a number is refused")
        func lengthMustBeANumber() {
            #expect(throws: HookError.self) { try HookRequest.parse("scene.dump lots\n") }
        }

        @Test("A payload shorter than its length is refused")
        func shortPayloadIsRefused() {
            #expect(throws: HookError.self) { try HookRequest.parse("scene.dump 50\n{}") }
        }

        @Test("A message split inside a character still arrives as it was sent")
        func splitInsideACharacter() throws {
            let japanese = "{\"label\": \"\u{4FDD}\u{5B58}\"}"
            let whole = Array(HookRequest(name: "input.replay", payload: japanese).text.utf8)

            for point in 1..<whole.count {
                #expect(throws: HookError.self) { try HookRequest.parse(Array(whole[..<point])) }
            }
            #expect(try HookRequest.parse(whole).payload == japanese)
        }

        @Test("A reply carries its length the same way")
        func replyRoundTrips() throws {
            for reply in [HookReply.ok("{\"a\": 1}"), HookReply.failed("no such thing")] {
                #expect(try HookReply.parse(reply.text) == reply)
            }
        }

        @Test("A reply says whether it worked without anybody parsing the payload")
        func replySaysWhetherItWorked() {
            #expect(HookReply.ok("").worked)
            #expect(!HookReply.failed("why").worked)
        }
    }

    @Suite("Hook routing")
    struct HookRoutingTests {

        private func router() -> HookRouter {
            HookRouter(handlers: [
                HookRouter.Named(name: "echo", handle: { $0 }),
                HookRouter.Named(name: "boom", handle: { _ in throw HookError(detail: "it went wrong") }),
            ])
        }

        @Test("A request reaches the handler with its name")
        func routesByName() {
            let reply = router().reply(to: HookRequest(name: "echo", payload: "hello"))
            #expect(reply.worked)
            #expect(reply.payload == "hello")
        }

        @Test("An unknown name is refused, and the reply lists what is known")
        func unknownNameIsRefused() {
            let reply = router().reply(to: HookRequest(name: "nope", payload: ""))
            #expect(!reply.worked)
            #expect(reply.payload.contains("echo"))
            #expect(reply.payload.contains("boom"))
        }

        @Test("What is known is listed in the same order every time")
        func knownNamesAreOrdered() {
            let first = router().reply(to: HookRequest(name: "nope", payload: "")).payload
            let second = router().reply(to: HookRequest(name: "nope", payload: "")).payload
            #expect(first == second)
        }

        @Test("A handler that throws becomes a reply, not a broken connection")
        func throwingHandlerRepliesInstead() {
            let reply = router().reply(to: HookRequest(name: "boom", payload: ""))
            #expect(!reply.worked)
            #expect(reply.payload.contains("it went wrong"))
        }

        @Test("Two handlers cannot share a name")
        func namesAreUnique() {
            #expect(throws: HookError.self) {
                try HookRouter.checked(handlers: [
                    HookRouter.Named(name: "same", handle: { $0 }),
                    HookRouter.Named(name: "same", handle: { $0 }),
                ])
            }
        }
    }
#endif
