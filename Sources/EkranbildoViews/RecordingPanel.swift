import AppKit
import SwiftUI

public struct RecordingPanelView: View {
    @State private var seconds: Double
    @State private var dropped: Int
    private let stop: () -> Void

    public init(seconds: Double = 0, dropped: Int = 0, stop: @escaping () -> Void) {
        _seconds = State(initialValue: seconds)
        _dropped = State(initialValue: dropped)
        self.stop = stop
    }

    public var body: some View {
        HStack(spacing: Size.gap) {
            Circle()
                .fill(.red)
                .frame(width: Size.dot, height: Size.dot)
            Text(Self.clock(seconds))
                .font(.system(.title3, design: .monospaced))
            if dropped > 0 {
                Text("\(dropped) dropped")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Button("Stop", action: stop)
                .keyboardShortcut(.defaultAction)
        }
        .padding()
    }

    static func clock(_ seconds: Double) -> String {
        let whole = Int(seconds)
        let minutes = whole / Clock.perMinute
        let rest = whole % Clock.perMinute
        return String(format: "%d:%02d", minutes, rest)
    }

    private enum Clock {
        static let perMinute = 60
    }

    private enum Size {
        static let gap: Double = 10
        static let dot: Double = 10
    }

    var stopping: () -> Void { stop }
}

@MainActor
public final class RecordingPanelController: NSWindowController {
    private let host: NSHostingView<RecordingPanelView>

    public init(stop: @escaping () -> Void) {
        host = NSHostingView(rootView: RecordingPanelView(stop: stop))
        let window = NSPanel(
            contentRect: .zero,
            styleMask: [.titled, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.title = "Recording"
        window.isFloatingPanel = true
        window.level = .floating
        window.contentView = host
        window.setContentSize(host.fittingSize)
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { nil }

    public func show(seconds: Double, dropped: Int) {
        host.rootView = RecordingPanelView(
            seconds: seconds, dropped: dropped, stop: host.rootView.stopping)
    }
}
