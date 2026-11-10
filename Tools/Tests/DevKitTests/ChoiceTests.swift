@testable import DevKit
import Testing

@Suite("Every choice is made in full")
struct ChoiceTests {
    private func findings(_ source: String, ours: Set<String> = ["red", "green", "moved"])
        -> [Finding]
    {
        ChoiceRules.findings(in: source, path: "Sources/Whatever.swift", ours: ours)
    }

    @Test("A switch over cases that names them all is left alone")
    func exhaustive() {
        #expect(
            findings(
                """
                func f(_ colour: Colour) -> Int {
                    switch colour {
                    case .red: 1
                    case .green: 2
                    }
                }
                """
            ).isEmpty)
    }

    @Test("A switch over cases that ends in a catch-all is a place a new case can hide")
    func catchAll() {
        let found = findings(
            """
            func f(_ colour: Colour) -> Int {
                switch colour {
                case .red: 1
                default: 0
                }
            }
            """
        )
        #expect(found.count == 1)
        #expect(found.first?.line == 4)
    }

    @Test("A switch over something with no cases at all may catch what is left")
    func notCases() {
        #expect(
            findings(
                """
                func f(_ character: Character) -> String {
                    switch character {
                    case "<": "&lt;"
                    default: String(character)
                    }
                }
                """
            ).isEmpty)
    }

    @Test("A switch over pairs may catch what is left")
    func tuples() {
        #expect(
            findings(
                """
                func f(_ pressed: Bool, _ shifted: Bool) -> Int {
                    switch (pressed, shifted) {
                    case (true, true): 1
                    default: 0
                    }
                }
                """
            ).isEmpty)
    }

    @Test("A case carrying a value still counts as a case")
    func caseWithPayload() {
        #expect(
            findings(
                """
                func f(_ event: Event) {
                    switch event {
                    case .moved(let to): use(to)
                    default: break
                    }
                }
                """
            ).count == 1)
    }

    @Test("A catch-all that binds a name is the same hiding place under another spelling")
    func bindingCatchAll() {
        #expect(
            findings(
                """
                func f(_ colour: Colour) -> Int {
                    switch colour {
                    case .red: 1
                    case let other: fallback(other)
                    }
                }
                """
            ).count == 1)
    }

    @Test("Several cases on one line are all seen")
    func severalOnALine() {
        #expect(
            findings(
                """
                func f(_ colour: Colour) -> Int {
                    switch colour {
                    case .red, .green: 1
                    default: 0
                    }
                }
                """
            ).count == 1)
    }

    @Test("Saying why in one place does not excuse it")
    func noQuietWaiver() {
        #expect(
            !findings(
                """
                func f(_ colour: Colour) -> Int {
                    switch colour {
                    case .red: 1
                    default: 0
                    }
                }
                """
            ).isEmpty)
    }

    @Test("Cases of a type we did not declare are not ours to name in full")
    func somebodyElsesEnum() {
        #expect(
            findings(
                """
                func f(_ event: NSEvent) {
                    switch event.type {
                    case .leftMouseDown: down()
                    default: break
                    }
                }
                """
            ).isEmpty)
    }

    @Test("What our own enums declare is gathered from the sources themselves")
    func gathersOurCases() {
        let gathered = ChoiceRules.casesWeDeclare(
            in: """
            public enum Colour {
                case red
                case green, blue
                case shaded(Double)
            }
            """
        )
        #expect(gathered == ["red", "green", "blue", "shaded"])
    }

    @Test("Cases somebody else may add later are not ours to name")
    func unknownDefault() {
        #expect(
            findings(
                """
                func f(_ result: Product.PurchaseResult) -> Int {
                    switch result {
                    case .success: 1
                    case .pending: 2
                    @unknown default: 0
                    }
                }
                """
            ).isEmpty)
    }

    @Test("Advice says what to do rather than only what is wrong")
    func advice() {
        let found = findings(
            """
            func f(_ colour: Colour) -> Int {
                switch colour {
                case .red: 1
                default: 0
                }
            }
            """
        )
        #expect(found.first?.advice.contains("every case") == true)
    }
}
