import AppKit
import EkranbildoContracts
import EkranbildoCore

@MainActor
public final class EditorWindowController: NSWindowController {
    private let canvas: CanvasView

    public var cameForward: (@MainActor () -> Void)?
    public var wentAway: (@MainActor () -> Void)?

    public init(scene: Scene, title: String, assets: (any AssetStoring)? = nil) {
        canvas = CanvasView(scene: scene, assets: assets)

        let scroll = NSScrollView()
        scroll.documentView = canvas
        scroll.allowsMagnification = true
        scroll.minMagnification = Zoom.smallest
        scroll.maxMagnification = Zoom.largest
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true

        let window = NSWindow(
            contentRect: NSRect(
                origin: .zero,
                size: NSSize(width: scene.canvas.width, height: scene.canvas.height)),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentView = scroll
        window.center()
        super.init(window: window)

        window.makeFirstResponder(canvas)
        window.toolbar = makeToolbar()
        window.delegate = self
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { nil }

    public var scene: Scene {
        get { canvas.scene }
        set { canvas.scene = newValue }
    }

    public var send: (@MainActor (InputEvent) -> Void)? {
        get { canvas.send }
        set { canvas.send = newValue }
    }

    public func choose(_ tool: ToolID) {
        send?(.toolSelected(tool))
    }

    public var tool: ToolID = .select {
        didSet { window?.toolbar?.selectedItemIdentifier = Self.item(for: tool) }
    }

    fileprivate static func item(for tool: ToolID) -> NSToolbarItem.Identifier? {
        Tools.all.first { $0.id == tool }?.item
    }

    private enum Zoom {
        static let smallest = 0.1
        static let largest = 8.0
    }

    private func makeToolbar() -> NSToolbar {
        let toolbar = NSToolbar(identifier: "editor")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        return toolbar
    }

    @objc private func chooseTool(_ sender: NSToolbarItem) {
        guard let tool = Tools.all.first(where: { $0.item.rawValue == sender.itemIdentifier.rawValue })
        else { return }
        choose(tool.id)
    }

    fileprivate struct Tool {
        let id: ToolID
        let item: NSToolbarItem.Identifier
        let symbol: String
        let title: String
    }

    fileprivate enum Tools {
        static let all: [Tool] = [
            Tool(
                id: .select,
                item: NSToolbarItem.Identifier("select"),
                symbol: "cursorarrow",
                title: "Select"
            ),
            Tool(
                id: .annotate,
                item: NSToolbarItem.Identifier("annotate"),
                symbol: "arrow.up.left.circle",
                title: "Point at"
            ),
            Tool(
                id: .redact,
                item: NSToolbarItem.Identifier("redact"),
                symbol: "eye.slash",
                title: "Hide"
            ),
        ]
    }
}

extension EditorWindowController: NSWindowDelegate {
    public func windowDidBecomeKey(_ notification: Notification) {
        cameForward?()
    }

    public func windowWillClose(_ notification: Notification) {
        wentAway?()
    }
}

extension EditorWindowController: NSToolbarDelegate {
    public func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar)
        -> [NSToolbarItem.Identifier]
    {
        Tools.all.map(\.item)
    }

    public func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Tools.all.map(\.item)
    }

    public func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    public func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard let tool = Tools.all.first(where: { $0.item == identifier }) else { return nil }
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = tool.title
        item.toolTip = tool.title
        item.image = NSImage(systemSymbolName: tool.symbol, accessibilityDescription: tool.title)
        item.target = self
        item.action = #selector(chooseTool(_:))
        item.isBordered = true
        return item
    }
}
