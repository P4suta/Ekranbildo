import AppKit
import EkranbildoShell
import SwiftUI

public struct WelcomeView: View {
    private let step: OnboardingStep
    private let act: () -> Void

    public init(step: OnboardingStep, act: @escaping () -> Void) {
        self.step = step
        self.act = act
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Size.spacing) {
            Image(systemName: Self.symbol(for: step.stage))
                .font(.system(size: Size.symbol))
                .foregroundStyle(.tint)

            Text(step.title)
                .font(.title2)
                .bold()

            Text(step.instruction)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HStack {
                ForEach(OnboardingStage.allCases, id: \.self) { stage in
                    Circle()
                        .fill(
                            stage == step.stage
                                ? Color.accentColor
                                : Color.secondary.opacity(
                                    Size.dimmedDot)
                        )
                        .frame(width: Size.dot, height: Size.dot)
                }
                Spacer()
                if let button = Self.button(for: step.stage) {
                    Button(button, action: act)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(Size.padding)
        .frame(width: Size.width, height: Size.height)
    }

    static func symbol(for stage: OnboardingStage) -> String {
        switch stage {
        case .askForPermission: "hand.raised"
        case .openSettings: "exclamationmark.triangle"
        case .restart: "arrow.clockwise"
        case .tryIt: "camera.viewfinder"
        case .done: "checkmark.circle"
        }
    }

    static func button(for stage: OnboardingStage) -> String? {
        switch stage {
        case .askForPermission: "Ask macOS"
        case .openSettings: "Open System Settings"
        case .restart: "Quit Ekranbildo"
        case .tryIt: "Capture now"
        case .done: nil
        }
    }

    private enum Size {
        static let width: Double = 420
        static let height: Double = 260
        static let padding: Double = 24
        static let spacing: Double = 12
        static let symbol: Double = 40
        static let dot: Double = 6
        static let dimmedDot: Double = 0.3
    }
}

@MainActor
public final class WelcomeWindowController: NSWindowController {
    private let act: () -> Void

    public init(step: OnboardingStep, act: @escaping () -> Void) {
        self.act = act
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Ekranbildo"
        window.contentView = NSHostingView(rootView: WelcomeView(step: step, act: act))
        window.setContentSize(window.contentView?.fittingSize ?? .zero)
        window.center()
        super.init(window: window)
    }

    public func show(_ step: OnboardingStep) {
        window?.contentView = NSHostingView(rootView: WelcomeView(step: step, act: act))
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { nil }
}
