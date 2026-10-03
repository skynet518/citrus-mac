import AppKit
import SwiftUI
import Observation

// Window placement is shared by restoration, display changes and dragging.
enum DesktopPlacement {
    static let size: CGFloat = 68
    static func clamp(_ origin: CGPoint, to frame: CGRect) -> CGPoint {
        CGPoint(x: min(max(origin.x, frame.minX + 8), max(frame.minX + 8, frame.maxX - size - 8)),
                y: min(max(origin.y, frame.minY + 8), max(frame.minY + 8, frame.maxY - size - 8)))
    }
    static func restore(_ origin: CGPoint?, screens: [CGRect]) -> CGPoint {
        guard let first = screens.first else { return .zero }
        guard let origin, origin.x.isFinite, origin.y.isFinite else {
            return clamp(CGPoint(x: first.maxX - size - 28, y: first.midY - size / 2), to: first)
        }
        let center = CGPoint(x: origin.x + size / 2, y: origin.y + size / 2)
        let screen = screens.first { $0.contains(center) } ?? screens.min {
            hypot($0.midX - center.x, $0.midY - center.y) < hypot($1.midX - center.x, $1.midY - center.y)
        } ?? first
        return clamp(origin, to: screen)
    }
    static func wheelCenter(button: CGRect, screen: CGRect) -> CGPoint {
        let half = RadialGeometry.diameter / 2, gap: CGFloat = 12
        let candidates = [CGPoint(x: button.minX - half - gap, y: button.midY),
                          CGPoint(x: button.maxX + half + gap, y: button.midY),
                          CGPoint(x: button.midX, y: button.maxY + half + gap),
                          CGPoint(x: button.midX, y: button.minY - half - gap)]
        for candidate in candidates {
            let frame = RadialGeometry.frame(center: candidate, screen: screen)
            if !frame.intersects(button.insetBy(dx: -6, dy: -6)) { return CGPoint(x: frame.midX, y: frame.midY) }
        }
        return CGPoint(x: screen.midX, y: screen.midY)
    }
}

@MainActor @Observable
final class DesktopButtonPreferences {
    private let defaults: UserDefaults
    var visible: Bool { didSet { defaults.set(visible, forKey: "desktopButtonVisible") } }
    var desktopOnly: Bool { didSet { defaults.set(desktopOnly, forKey: "desktopButtonDesktopOnly") } }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        visible = defaults.object(forKey: "desktopButtonVisible") as? Bool ?? true
        desktopOnly = defaults.bool(forKey: "desktopButtonDesktopOnly")
    }
    var savedOrigin: CGPoint? {
        guard let x = defaults.object(forKey: "desktopButtonX") as? Double,
              let y = defaults.object(forKey: "desktopButtonY") as? Double else { return nil }
        return CGPoint(x: x, y: y)
    }
    func save(origin: CGPoint) { defaults.set(origin.x, forKey: "desktopButtonX"); defaults.set(origin.y, forKey: "desktopButtonY") }
    func resetPosition() { defaults.removeObject(forKey: "desktopButtonX"); defaults.removeObject(forKey: "desktopButtonY") }
}

@MainActor final class DesktopButtonPanel: NSPanel, NSDraggingDestination {
    weak var dragTarget: DesktopButtonDropView?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    func draggingEntered(_ sender:NSDraggingInfo) -> NSDragOperation { dragTarget?.draggingEntered(sender) ?? [] }
    func draggingUpdated(_ sender:NSDraggingInfo) -> NSDragOperation { dragTarget?.draggingUpdated(sender) ?? [] }
    func draggingExited(_ sender:NSDraggingInfo?) { dragTarget?.draggingExited(sender) }
    func prepareForDragOperation(_ sender:NSDraggingInfo) -> Bool { dragTarget?.prepareForDragOperation(sender) ?? false }
    func performDragOperation(_ sender:NSDraggingInfo) -> Bool { dragTarget?.performDragOperation(sender) ?? false }
    func draggingEnded(_ sender:NSDraggingInfo) { dragTarget?.draggingEnded(sender) }
}

@MainActor final class DesktopButtonDropView: NSView {
    var onChoose: (() -> Void)?
    var onPreview: (([URL]) -> Void)?
    var onStage: (([URL]) -> Void)?
    var onExit: (() -> Void)?
    var onMove: ((CGPoint, Bool) -> Void)?
    var onMenu: (() -> NSMenu)?
    private var mouseAnchor = CGPoint.zero
    private var originAnchor = CGPoint.zero
    private var moved = false
    private var imageView: NSImageView!
    private var glass: NSView!
    private var hover = false
    override init(frame: CGRect) {
        super.init(frame: frame)
        let content = NSView(frame: CGRect(x: 0, y: 0, width: 54, height: 54))
        imageView = NSImageView(frame: CGRect(x: 12, y: 12, width: 30, height: 30))
        let icon = CitrusStatusIcon.make(); icon.isTemplate = true
        imageView.image = icon; imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.contentTintColor = CitrusTheme.accentColor
        imageView.setAccessibilityElement(false)
        content.autoresizingMask = [.width, .height]
        imageView.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        content.addSubview(imageView)
        if #available(macOS 26.0, *) {
            let effect = NSGlassEffectView(frame: CGRect(x: 7, y: 7, width: 54, height: 54))
            effect.style = .regular; effect.cornerRadius = 27; effect.contentView = content
            glass = effect
        } else {
            let effect = NSVisualEffectView(frame: CGRect(x: 7, y: 7, width: 54, height: 54))
            effect.material = .popover; effect.blendingMode = .behindWindow; effect.state = .active
            effect.wantsLayer = true; effect.layer?.cornerRadius = 27; effect.layer?.masksToBounds = true
            effect.addSubview(content); glass = effect
        }
        addSubview(glass)
        registerForDraggedTypes([.fileURL, NSPasteboard.PasteboardType("NSFilenamesPboardType")])
        toolTip = "拖入文件，打开圆盘 · 拖动橘子可移动 · 右键设置"
        setAccessibilityElement(true); setAccessibilityRole(.button); setAccessibilityLabel("橘子桌面按钮")
        setAccessibilityHelp("拖入文件打开圆盘。点击选择文件，拖动移动位置，右键设置显示层级。")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
    override var needsPanelToBecomeKey: Bool { false }
    override func acceptsFirstMouse(for event:NSEvent?) -> Bool { true }
    override func draw(_ dirtyRect:NSRect) {
        // Keep a painted hit region underneath compositor-rendered glass.
        NSColor.windowBackgroundColor.withAlphaComponent(0.08).setFill()
        NSBezierPath(ovalIn:bounds.insetBy(dx:7,dy:7)).fill()
    }
    override func hitTest(_ point: NSPoint) -> NSView? { bounds.contains(point) ? self : nil }
    override func accessibilityPerformPress() -> Bool { onChoose?(); return true }
    override func updateTrackingAreas() {
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
        super.updateTrackingAreas()
    }
    override func mouseEntered(with event: NSEvent) { hover = true; refresh(dragging: false) }
    override func mouseExited(with event: NSEvent) { hover = false; refresh(dragging: false) }
    private func refresh(dragging: Bool) {
        imageView.contentTintColor = dragging ? .labelColor : CitrusTheme.accentColor
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.15
            glass.animator().frame = (hover || dragging) ? CGRect(x: 4, y: 4, width: 60, height: 60) : CGRect(x: 7, y: 7, width: 54, height: 54)
        }
    }
    override func mouseDown(with event: NSEvent) {
        mouseAnchor = NSEvent.mouseLocation; originAnchor = window?.frame.origin ?? .zero; moved = false
    }
    override func mouseDragged(with event: NSEvent) {
        let mouse = NSEvent.mouseLocation
        let delta = CGPoint(x: mouse.x - mouseAnchor.x, y: mouse.y - mouseAnchor.y)
        if hypot(delta.x, delta.y) > 3 { moved = true }
        if moved { onMove?(CGPoint(x: originAnchor.x + delta.x, y: originAnchor.y + delta.y), false) }
    }
    override func mouseUp(with event: NSEvent) {
        if moved { onMove?(window?.frame.origin ?? originAnchor, true) } else { onChoose?() }
    }
    override func rightMouseDown(with event: NSEvent) { if let menu = onMenu?() { NSMenu.popUpContextMenu(menu, with: event, for: self) } }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let urls = DragFiles.read(sender.draggingPasteboard)
        EventReceipt.record("desktop_button_drag_probe",["types":(sender.draggingPasteboard.types ?? []).map(\.rawValue),"supported_count":urls.count])
        guard !urls.isEmpty else { return [] }
        refresh(dragging: true); onPreview?(urls)
        EventReceipt.record("desktop_button_drag_entered", ["count": urls.count, "modifiers_required": false])
        return .copy
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { DragFiles.read(sender.draggingPasteboard).isEmpty ? [] : .copy }
    override func draggingExited(_ sender: NSDraggingInfo?) { refresh(dragging: false); onExit?() }
    override func draggingEnded(_ sender: NSDraggingInfo) { refresh(dragging:false); onExit?() }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { !DragFiles.read(sender.draggingPasteboard).isEmpty }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = DragFiles.read(sender.draggingPasteboard)
        guard !urls.isEmpty else { return false }
        refresh(dragging: false)
        EventReceipt.record("desktop_button_drop_received", ["count": urls.count, "source": sender.draggingSource is PracticeFile ? "practice" : "external"])
        DispatchQueue.main.async { [weak self] in self?.onStage?(urls) }
        return true
    }
}

@MainActor final class DesktopButtonController {
    let preferences: DesktopButtonPreferences
    let panel: DesktopButtonPanel
    private let dropView: DesktopButtonDropView
    let radial: RadialController
    var onChoose: (() -> Void)?
    var onSettings: (() -> Void)?
    var onChanged: (() -> Void)?
    init(radial: RadialController, preferences: DesktopButtonPreferences? = nil) {
        self.radial = radial; self.preferences = preferences ?? DesktopButtonPreferences()
        panel = DesktopButtonPanel(contentRect: CGRect(x: 0, y: 0, width: 68, height: 68), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "橘子桌面按钮"; panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
        panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true; panel.worksWhenModal = true; panel.ignoresMouseEvents = false
        panel.isFloatingPanel = true; panel.canHide = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        dropView = DesktopButtonDropView(frame: CGRect(x: 0, y: 0, width: 68, height: 68)); panel.contentView = dropView
        panel.dragTarget = dropView
        panel.registerForDraggedTypes([.fileURL, NSPasteboard.PasteboardType("NSFilenamesPboardType")])
        dropView.onChoose = { [weak self] in self?.onChoose?() }
        dropView.onPreview = { [weak self] urls in self?.preview(urls) }
        dropView.onStage = { [weak self] urls in self?.preview(urls); self?.radial.pin() }
        dropView.onExit = { [weak self] in self?.radial.scheduleDragDismissal() }
        dropView.onMove = { [weak self] origin, finished in self?.move(to: origin, finished: finished) }
        dropView.onMenu = { [weak self] in self?.contextMenu() ?? NSMenu() }
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        restorePosition(); apply()
    }
    func restorePosition() { panel.setFrameOrigin(DesktopPlacement.restore(preferences.savedOrigin, screens: NSScreen.screens.map(\.visibleFrame))) }
    @objc func screenChanged() { preferences.save(origin: panel.frame.origin); restorePosition() }
    func move(to origin: CGPoint, finished: Bool) {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        panel.setFrameOrigin(DesktopPlacement.clamp(origin, to: screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)))
        if finished { preferences.save(origin: panel.frame.origin); EventReceipt.record("desktop_button_moved", ["x": panel.frame.minX, "y": panel.frame.minY]) }
    }
    func apply() {
        panel.level = preferences.desktopOnly ? NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1) : .floating
        if preferences.visible {
            panel.orderFrontRegardless()
            panel.registerForDraggedTypes([.fileURL, NSPasteboard.PasteboardType("NSFilenamesPboardType")])
        } else { panel.orderOut(nil) }
        onChanged?()
        EventReceipt.record("desktop_button_preferences", ["visible": preferences.visible, "desktop_only": preferences.desktopOnly, "level": panel.level.rawValue,"x":panel.frame.minX,"y":panel.frame.minY,"width":panel.frame.width,"height":panel.frame.height,"window_visible":panel.isVisible,"active_space":panel.isOnActiveSpace])
    }
    private func preview(_ urls: [URL]) {
        let screen = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let center = DesktopPlacement.wheelCenter(button: panel.frame, screen: screen)
        radial.show(urls: urls, at: center, tools: false, entry: .desktopButton)
    }
    func resetPosition() { preferences.resetPosition(); restorePosition(); preferences.save(origin: panel.frame.origin); apply() }
    @objc func toggleVisible() { preferences.visible.toggle(); apply() }
    @objc func toggleLayer() { preferences.desktopOnly.toggle(); apply() }
    @objc func resetFromMenu() { resetPosition() }
    @objc func settingsFromMenu() { onSettings?() }
    @objc func chooseFromMenu() { onChoose?() }
    func contextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "选择文件…", action: #selector(chooseFromMenu), keyEquivalent: "").target = self
        menu.addItem(.separator())
        let layer = menu.addItem(withTitle: "仅固定在桌面图层", action: #selector(toggleLayer), keyEquivalent: ""); layer.target = self; layer.state = preferences.desktopOnly ? .on : .off
        menu.addItem(withTitle: "恢复默认位置", action: #selector(resetFromMenu), keyEquivalent: "").target = self
        menu.addItem(withTitle: "桌面按钮设置…", action: #selector(settingsFromMenu), keyEquivalent: "").target = self
        menu.addItem(withTitle: "隐藏桌面按钮", action: #selector(toggleVisible), keyEquivalent: "").target = self
        return menu
    }
}

struct DesktopButtonSettingsView: View {
    @Bindable var preferences: DesktopButtonPreferences
    let onChanged: () -> Void
    let onReset: () -> Void
    let onClose: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            EditorHeader(title: "桌面按钮", onClose: onClose)
            Divider().opacity(0.5)
            VStack(alignment: .leading, spacing: 22) {
                Toggle("显示小橘子", isOn: $preferences.visible).onChange(of: preferences.visible) { _, _ in onChanged() }
                VStack(alignment: .leading, spacing: 10) {
                    Text("显示层级").font(.system(size: 13, weight: .semibold))
                    Picker("显示层级", selection: $preferences.desktopOnly) {
                        Text("浮在窗口上方").tag(false); Text("仅在桌面").tag(true)
                    }.pickerStyle(.segmented).labelsHidden().onChange(of: preferences.desktopOnly) { _, _ in onChanged() }
                    Text(preferences.desktopOnly ? "回到桌面时可见，打开的应用窗口会覆盖它。" : "在其他应用上方保持可见，方便从 Finder 拖入文件。")
                        .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                HStack { Text("直接拖动小橘子可调整位置。").font(.system(size: 12)).foregroundStyle(.secondary); Spacer(); Button("重置位置", action: onReset).buttonStyle(CitrusButtonStyle()) }
            }.padding(24)
            Divider().opacity(0.5)
            HStack { Text("位置和显示方式会自动保存").font(.system(size: 11)).foregroundStyle(.secondary); Spacer(); Button("完成", action: onClose).buttonStyle(.borderedProminent).controlSize(.large) }.padding(20)
        }.frame(width: 430).foregroundStyle(CitrusTheme.ink).tint(CitrusTheme.orange).background(WarmGlass())
    }
}
