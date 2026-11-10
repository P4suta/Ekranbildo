import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoTestHooks
import Foundation

#if EKRANBILDO_TESTHOOKS
    func serveHooks(_ arguments: [String]) throws -> Never {
        let sceneJSON = try arguments.first.map {
            try String(contentsOfFile: $0, encoding: .utf8)
        }
        let scene =
            try sceneJSON.map { try JSONDecoder().decode(Scene.self, from: Data($0.utf8)) }
            ?? Scene(
                canvas: SceneRect(x: 0, y: 0, width: 0, height: 0),
                background: nil,
                annotations: [],
                style: .standard
            )

        let session = HookSession(scene: scene, measurer: TabulatedTextMeasurer.uniform())
        let router = session.router
        let input = FileHandle.standardInput
        let output = FileHandle.standardOutput

        var pending: [UInt8] = []
        while true {
            if let request = try? HookRequest.parse(pending) {
                let reply = router.reply(to: request)
                try output.write(contentsOf: Data(reply.text.utf8))
                pending.removeFirst(request.text.utf8.count)
                continue
            }
            let more = input.availableData
            guard !more.isEmpty else { break }
            pending.append(contentsOf: more)
        }
        exit(0)
    }
#endif
