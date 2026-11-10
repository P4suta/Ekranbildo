import AppKit
import EkranbildoStitch
import SwiftUI

public struct ScrollProgressView: View {
    @State private var seen: Int
    @State private var advice: ScrollAdvice
    private let finish: () -> Void
    private let cancel: () -> Void

    public init(
        seen: Int = 0,
        advice: ScrollAdvice = .keepGoing,
        finish: @escaping () -> Void,
        cancel: @escaping () -> Void
    ) {
        _seen = State(initialValue: seen)
        _advice = State(initialValue: advice)
        self.finish = finish
        self.cancel = cancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Size.gap) {
            Text(Self.said(advice))
                .font(.headline)
            Text("\(seen) rows so far")
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            HStack {
                Button("Cancel", role: .cancel, action: cancel)
                Spacer()
                Button("Done", action: finish)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: Size.width)
    }

    public func show(seen: Int, advice: ScrollAdvice) {
        self.seen = seen
        self.advice = advice
    }

    static func said(_ advice: ScrollAdvice) -> String {
        switch advice {
        case .keepGoing: "Scroll the page"
        case .slowDown: "Scroll a little more slowly"
        case .nothingIsMoving: "Nothing is moving yet"
        case .theScreenChanged: "The screen changed size, so this cannot be joined"
        }
    }

    private enum Size {
        static let width: Double = 260
        static let gap: Double = 8
    }
}

@MainActor
public final class ScrollProgressWindowController: NSWindowController {
    private let host: NSHostingView<ScrollProgressView>

    public init(finish: @escaping () -> Void, cancel: @escaping () -> Void) {
        host = NSHostingView(rootView: ScrollProgressView(finish: finish, cancel: cancel))
        let window = NSPanel(
            contentRect: .zero,
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.title = "Scrolling Capture"
        window.isFloatingPanel = true
        window.level = .floating
        window.contentView = host
        window.setContentSize(host.fittingSize)
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { nil }

    public func show(seen: Int, advice: ScrollAdvice) {
        host.rootView = ScrollProgressView(
            seen: seen,
            advice: advice,
            finish: host.rootView.finishing,
            cancel: host.rootView.cancelling
        )
    }
}

extension ScrollProgressView {
    var finishing: () -> Void { finish }
    var cancelling: () -> Void { cancel }
}
