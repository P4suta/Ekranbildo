import AppKit
import EkranbildoHotkeys
import EkranbildoShell
import SwiftUI

public struct SettingsView: View {
    @State private var settings: EkranbildoShell.Settings
    private let reset: [String]
    private let save: (EkranbildoShell.Settings) -> Void

    public init(
        settings: EkranbildoShell.Settings,
        reset: [String] = [],
        save: @escaping (EkranbildoShell.Settings) -> Void
    ) {
        _settings = State(initialValue: settings)
        self.reset = reset
        self.save = save
    }

    public var body: some View {
        Form {
            if !reset.isEmpty {
                Section {
                    ForEach(reset, id: \.self) { sentence in
                        Label(sentence, systemImage: "exclamationmark.triangle")
                            .font(.callout)
                    }
                } header: {
                    Text("Some settings were reset")
                }
            }

            Section {
                LabeledContent("Capture shortcut") {
                    Text(settings.captureShortcut.displayed)
                        .monospaced()
                }
                Toggle("Open the editor after a capture", isOn: $settings.opensEditorAfterCapture)
                Toggle("Copy to the clipboard", isOn: $settings.copiesToClipboard)
                Toggle(
                    "Hide passwords, keys and addresses automatically",
                    isOn: $settings.hidesSecretsAutomatically
                )
            } header: {
                Text("Capturing")
            }

            Section {
                ForEach(Finishing.allCases, id: \.self) { step in
                    Toggle(step.name, isOn: binding(for: step))
                }
            } header: {
                Text("Recording")
            }

            Section {
                Toggle("Include the pointer", isOn: $settings.includesPointer)
                Toggle("Keep the window's shadow", isOn: $settings.includesWindowShadow)
                LabeledContent("Export scale") {
                    Stepper(
                        value: $settings.exportScale,
                        in: Limits.scales,
                        step: Limits.scaleStep
                    ) {
                        Text("\(settings.exportScale, specifier: "%.0f")x")
                    }
                }
            } header: {
                Text("Pictures")
            }

            Section {
                LabeledContent("Captures to keep") {
                    Stepper(
                        value: $settings.libraryLimit,
                        in: Limits.history,
                        step: Limits.historyStep
                    ) {
                        Text("\(settings.libraryLimit)")
                    }
                }
            } header: {
                Text("History")
            }

            Section {
                Toggle("Allow diagnostic reports to be sent", isOn: $settings.sendsDiagnostics)
            } header: {
                Text("Privacy")
            } footer: {
                Text(
                    "A diagnostic report holds a picture of your screen. Nothing is ever "
                        + "sent without you choosing to send it, and you can see what is in "
                        + "one first."
                )
                .font(.footnote)
            }
        }
        .formStyle(.grouped)
        .frame(width: Size.width)
        .onChange(of: settings) { _, updated in save(updated) }
    }

    private func binding(for step: Finishing) -> Binding<Bool> {
        Binding(
            get: { settings.isOn(step) },
            set: { settings.turn(step, on: $0) }
        )
    }

    private enum Limits {
        static let scales: ClosedRange<Double> = 1...3
        static let scaleStep: Double = 1
        static let history: ClosedRange<Int> = 10...1000
        static let historyStep = 10
    }

    private enum Size {
        static let width: Double = 460
    }
}

@MainActor
public final class SettingsWindowController: NSWindowController {
    public init(
        settings: EkranbildoShell.Settings,
        reset: [String],
        save: @escaping (EkranbildoShell.Settings) -> Void
    ) {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Ekranbildo Settings"
        window.contentView = NSHostingView(
            rootView: SettingsView(settings: settings, reset: reset, save: save))
        window.setContentSize(window.contentView?.fittingSize ?? .zero)
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { nil }
}
