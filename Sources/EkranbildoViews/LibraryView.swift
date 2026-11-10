import AppKit
import EkranbildoContracts
import EkranbildoLibrary
import SwiftUI

public struct LibraryView: View {
    private let library: Library
    private let thumbnail: (ImageRef) -> NSImage?
    private let open: (CaptureID) -> Void

    public init(
        library: Library,
        thumbnail: @escaping (ImageRef) -> NSImage?,
        open: @escaping (CaptureID) -> Void
    ) {
        self.library = library
        self.thumbnail = thumbnail
        self.open = open
    }

    public var body: some View {
        Group {
            if library.entries.isEmpty {
                ContentUnavailableView(
                    "Nothing captured yet",
                    systemImage: "camera.viewfinder",
                    description: Text("Captures appear here, newest first.")
                )
            } else {
                List(library.entries) { entry in
                    Row(entry: entry, image: thumbnail(entry.image))
                        .contentShape(Rectangle())
                        .onTapGesture { open(entry.id) }
                }
            }
        }
        .frame(width: Size.width, height: Size.height)
    }

    private struct Row: View {
        let entry: LibraryEntry
        let image: NSImage?

        var body: some View {
            HStack(spacing: Size.gap) {
                Group {
                    if let image {
                        Image(nsImage: image)
                            .resizable().scaledToFit()
                    } else {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: Size.thumbnail, height: Size.thumbnail)

                VStack(alignment: .leading) {
                    Text(entry.source.described)
                    Text("\(entry.image.pixelWidth) x \(entry.image.pixelHeight)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, Size.rowPadding)
        }
    }

    private enum Size {
        static let width: Double = 360
        static let height: Double = 440
        static let thumbnail: Double = 44
        static let gap: Double = 10
        static let rowPadding: Double = 4
    }
}

extension LibraryEntry.Source {
    var described: String {
        switch self {
        case .region: "Region"
        case .window: "Window"
        case .display: "Screen"
        case .scroll: "Scrolling capture"
        case .recording: "Recording"
        case .imported: "Opened from a file"
        }
    }
}

@MainActor
public final class LibraryWindowController: NSWindowController {
    public var library: Library {
        didSet { host.rootView = view(library) }
    }

    private let host: NSHostingView<LibraryView>
    private let thumbnail: (ImageRef) -> NSImage?
    private let open: (CaptureID) -> Void

    private func view(_ library: Library) -> LibraryView {
        LibraryView(library: library, thumbnail: thumbnail, open: open)
    }

    public init(
        library: Library,
        thumbnail: @escaping (ImageRef) -> NSImage?,
        open: @escaping (CaptureID) -> Void
    ) {
        self.library = library
        self.thumbnail = thumbnail
        self.open = open
        host = NSHostingView(
            rootView: LibraryView(library: library, thumbnail: thumbnail, open: open))
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Ekranbildo History"
        window.contentView = host
        window.setContentSize(host.fittingSize)
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { nil }
}
