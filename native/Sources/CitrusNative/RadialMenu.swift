import AppKit
import SwiftUI

struct FrostedGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover; view.blendingMode = .behindWindow; view.state = .active
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

struct WarmGlass:View {
    @ViewBuilder var body:some View {
        if #available(macOS 26.0, *) { Color.clear } else { FrostedGlass() }
    }
}

@MainActor enum CitrusGlass {
    static func wrap(_ content:NSView,cornerRadius:CGFloat) -> NSView {
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView(frame:content.frame)
            glass.style = .regular; glass.cornerRadius = cornerRadius
            content.autoresizingMask = [.width,.height]; glass.contentView = content
            return glass
        }
        return content
    }
}

struct CitrusButtonStyle:ButtonStyle {
    var primary = false
    func makeBody(configuration:Configuration) -> some View {
        configuration.label
            .font(.system(size:14,weight:.medium)).padding(.horizontal,14).padding(.vertical,11)
            .foregroundStyle(primary ? Color.white : CitrusTheme.ink)
            .background(primary ? CitrusTheme.orange : CitrusTheme.surface,in:RoundedRectangle(cornerRadius:12))
            .overlay(RoundedRectangle(cornerRadius:12).stroke(primary ? Color.clear : CitrusTheme.border,lineWidth:1))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

enum CitrusTheme {
    static let accentColor = NSColor(calibratedRed: 0.64, green: 0.38, blue: 0.24, alpha: 1)
    static let orange = Color(nsColor: accentColor)
    static let ink = Color.primary
    static let surface = Color(nsColor: .controlBackgroundColor).opacity(0.55)
    static let border = Color(nsColor: .separatorColor).opacity(0.35)
}

struct Wedge: Shape {
    var index: Int
    var count: Int
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX,y: rect.midY)
        let step = 2 * CGFloat.pi / CGFloat(max(1,count))
        let theta = -CGFloat.pi/2 + CGFloat(index)*step
        let start = theta - step/2 + 0.025, end = theta + step/2 - 0.025
        let outer: CGFloat = 157, inner: CGFloat = 63
        func p(_ r: CGFloat, _ angle: CGFloat) -> CGPoint { CGPoint(x:center.x+r*cos(angle),y:center.y+r*sin(angle)) }
        var path = Path()
        path.move(to: p(outer-10,start))
        path.addQuadCurve(to: p(outer,start+0.055), control: p(outer,start))
        path.addArc(center: center,radius: outer,startAngle: .radians(start+0.055),endAngle: .radians(end-0.055),clockwise:false)
        path.addQuadCurve(to:p(outer-10,end),control:p(outer,end))
        path.addLine(to:p(inner+9,end))
        path.addQuadCurve(to:p(inner,end-0.065),control:p(inner,end))
        path.addArc(center:center,radius:inner,startAngle:.radians(end-0.065),endAngle:.radians(start+0.065),clockwise:true)
        path.addQuadCurve(to:p(inner+9,start),control:p(inner,start))
        path.closeSubpath(); return path
    }
}

struct RadialMenuView: View {
    let state: RadialState
    var onCancel: (() -> Void)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            Circle().fill(.clear).background(WarmGlass().clipShape(Circle()))
                .overlay(Circle().stroke(CitrusTheme.border,lineWidth:0.8)).padding(8)
            ForEach(Array(state.actions.enumerated()),id:\.offset) { n, action in
                let selected = state.selected == n
                Wedge(index:n,count:state.actions.count)
                    .fill(selected ? CitrusTheme.orange : CitrusTheme.surface)
                    .overlay(Wedge(index:n,count:state.actions.count).stroke(CitrusTheme.border,lineWidth:0.5))
                VStack(spacing:5) {
                    if let symbol = action.symbol { Image(systemName:symbol).font(.system(size:17,weight:.medium)) }
                    Text(action.title).font(.system(size:action.symbol == nil ? 14 : 11,weight:.semibold))
                }
                .foregroundStyle(selected ? .white : CitrusTheme.ink)
                .position(labelPosition(n,count:state.actions.count))
            }
            Text(state.action?.title ?? (state.allowsStaging && !state.pinned ? "放下后选择" : "选择操作"))
                .font(.system(size:10,weight:.medium)).foregroundStyle(.secondary).lineLimit(1)
                .frame(width:102).position(x:170,y:140)
            HStack(spacing:4) { modeButton("格式",tools:false); modeButton("工具",tools:true) }.position(x:170,y:169)
            Button(action:{ onCancel?() }) { Image(systemName:"xmark").font(.system(size:10,weight:.medium)).frame(width:32,height:22) }
                .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("关闭圆盘").position(x:170,y:199)
        }
        .frame(width:RadialGeometry.diameter,height:RadialGeometry.diameter)
        .scaleEffect(state.appeared || reduceMotion ? 1 : 0.94).opacity(state.appeared ? 1 : 0)
        .animation(reduceMotion ? nil : .spring(response:0.24,dampingFraction:0.9),value:state.appeared)
        .animation(reduceMotion ? nil : .easeOut(duration:0.10),value:state.selected)
        .accessibilityElement(children:.contain)
        .accessibilityLabel(state.tools ? "文件工具圆形菜单" : "格式转换圆形菜单")
    }
    func modeButton(_ title:String,tools:Bool) -> some View {
        Button(action:{ state.setMode(tools:tools) }) {
            Text(title).font(.system(size:12,weight:.medium)).frame(width:44,height:26)
                .foregroundStyle(state.tools == tools ? Color.white : CitrusTheme.ink)
                .background(state.tools == tools ? CitrusTheme.orange : CitrusTheme.surface,in:Capsule())
        }.buttonStyle(.plain).accessibilityLabel("切换到\(title)").accessibilityAddTraits(state.tools == tools ? .isSelected : [])
    }
    func labelPosition(_ n: Int,count: Int) -> CGPoint {
        let theta = -CGFloat.pi/2 + CGFloat(n)*2*CGFloat.pi/CGFloat(max(1,count))
        return CGPoint(x:170+110*cos(theta),y:170+110*sin(theta))
    }
}

@MainActor
final class RadialPanel: NSPanel {
    var onKey: ((NSEvent) -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func keyDown(with event: NSEvent) { onKey?(event) }
    override func flagsChanged(with event: NSEvent) { onKey?(event) }
}

@MainActor
final class RadialDropView: NSView {
    let state: RadialState
    var onPerform: (([URL],RadialAction) -> Void)?
    var onCancel: (() -> Void)?
    var onStage: (() -> Void)?
    var onDragExit: (() -> Void)?
    var tracking: NSTrackingArea?
    private var hoverMode: Bool?
    private var hoverGeneration = 0
    init(state: RadialState) {
        self.state = state
        super.init(frame:CGRect(x:0,y:0,width:340,height:340))
        registerForDraggedTypes([.fileURL, NSPasteboard.PasteboardType("NSFilenamesPboardType")])
        let host = NSHostingView(rootView:RadialMenuView(state:state,onCancel:{ [weak self] in self?.onCancel?() }))
        host.frame = bounds; host.autoresizingMask = [.width,.height]; addSubview(host)
        setAccessibilityElement(true); setAccessibilityRole(.group); setAccessibilityLabel("圆形转换菜单")
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) unavailable") }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func hitTest(_ point:NSPoint) -> NSView? {
        guard bounds.contains(point) else { return nil }
        if hypot(point.x-170,point.y-170) < 58 { return super.hitTest(point) }
        return self
    }
    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect:bounds,options:[.mouseMoved,.activeAlways,.inVisibleRect],owner:self,userInfo:nil)
        addTrackingArea(tracking!); super.updateTrackingAreas()
    }
    override func mouseMoved(with event:NSEvent) {
        state.update(point:convert(event.locationInWindow,from:nil), option:event.modifierFlags.contains(.option))
    }
    override func mouseDown(with event:NSEvent) {
        state.update(point:convert(event.locationInWindow,from:nil), option:event.modifierFlags.contains(.option))
        if let action = state.action { onPerform?(state.urls,action) } else { onCancel?() }
    }
    func urls(_ pasteboard:NSPasteboard) -> [URL] {
        DragFiles.read(pasteboard)
    }
    func update(_ sender:NSDraggingInfo) -> NSDragOperation {
        let incoming = urls(sender.draggingPasteboard)
        guard !incoming.isEmpty else { return [] }
        state.urls = incoming
        state.dragHover = true
        let point = convert(sender.draggingLocation,from:nil)
        state.update(point:point,option:NSEvent.modifierFlags.contains(.option))
        if state.entry != .systemDrag {
            let mode:Bool? = CGRect(x:124,y:156,width:44,height:26).contains(point) ? false : (CGRect(x:172,y:156,width:44,height:26).contains(point) ? true : nil)
            if hoverMode != mode {
                hoverMode = mode; hoverGeneration += 1
                let generation = hoverGeneration
                if let mode { DispatchQueue.main.asyncAfter(deadline:.now()+0.3) { [weak self] in
                    guard let self, self.hoverGeneration == generation, self.state.dragHover else { return }
                    self.state.setMode(tools:mode)
                } }
            }
        }
        let center = hypot(point.x-170,point.y-170) < RadialGeometry.innerRadius
        return state.action != nil || (state.allowsStaging && center) ? .copy : []
    }
    override func draggingEntered(_ sender:NSDraggingInfo) -> NSDragOperation { update(sender) }
    override func draggingUpdated(_ sender:NSDraggingInfo) -> NSDragOperation { update(sender) }
    override func wantsPeriodicDraggingUpdates() -> Bool { true }
    override func draggingExited(_ sender:NSDraggingInfo?) { state.selected = nil; state.dragHover = false; hoverMode = nil; hoverGeneration += 1; onDragExit?() }
    override func draggingEnded(_ sender:NSDraggingInfo) { state.dragHover = false; hoverMode = nil; hoverGeneration += 1; onDragExit?() }
    override func prepareForDragOperation(_ sender:NSDraggingInfo) -> Bool { update(sender) == .copy }
    override func performDragOperation(_ sender:NSDraggingInfo) -> Bool {
        _ = update(sender)
        let incoming = urls(sender.draggingPasteboard)
        guard !incoming.isEmpty else { return false }
        let point = convert(sender.draggingLocation,from:nil)
        if state.action == nil, state.allowsStaging, hypot(point.x-170,point.y-170) < RadialGeometry.innerRadius {
            EventReceipt.record("desktop_button_center_staged",["count":incoming.count])
            DispatchQueue.main.async { [weak self] in self?.onStage?() }
            return true
        }
        guard let action = state.action else { return false }
        EventReceipt.record("drop_received",["source":sender.draggingSource is PracticeFile ? "practice" : "external","action":action.title,"count":incoming.count,"local_x":point.x,"local_y":point.y])
        // Dispatch after AppKit finishes its drag session, before opening an editor.
        DispatchQueue.main.async { [weak self] in self?.onPerform?(incoming,action) }
        return true
    }
}

@MainActor
final class RadialController {
    let state = RadialState()
    private(set) var panel: RadialPanel!
    private var dropView: RadialDropView!
    var onAction: (([URL],RadialAction) -> Void)?
    private var dismissGeneration = 0
    private var outsideClick: Any?
    private var localClick: Any?
    var isVisible: Bool { panel?.isVisible ?? false }
    init() {
        panel = RadialPanel(contentRect:CGRect(x:0,y:0,width:340,height:340),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
        panel.level = .statusBar; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary,.transient]
        panel.acceptsMouseMovedEvents = true
        dropView = RadialDropView(state:state); panel.contentView = CitrusGlass.wrap(dropView,cornerRadius:170)
        dropView.onPerform = { [weak self] urls, action in self?.hide(); self?.onAction?(urls,action) }
        dropView.onCancel = { [weak self] in self?.hide() }
        dropView.onStage = { [weak self] in self?.pin() }
        dropView.onDragExit = { [weak self] in self?.scheduleDragDismissal() }
        panel.onKey = { [weak self] event in self?.key(event) }
        outsideClick = NSEvent.addGlobalMonitorForEvents(matching:[.leftMouseDown,.rightMouseDown]) { [weak self] _ in MainActor.assumeIsolated { self?.hide() } }
        localClick = NSEvent.addLocalMonitorForEvents(matching:[.leftMouseDown,.rightMouseDown]) { [weak self] event in
            if let self, self.isVisible, event.window !== self.panel { self.hide() }
            return event
        }
    }
    func show(urls:[URL],at center:CGPoint,tools:Bool,pinned:Bool=false,entry:RadialState.Entry? = nil) {
        guard !urls.isEmpty else { return }
        dismissGeneration += 1
        state.urls = urls; state.tools = tools; state.selected = nil; state.pinned = pinned; state.latchedTools = tools
        state.entry = entry ?? (pinned ? .filePicker : .systemDrag); state.dragHover = false
        let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main
        panel.setFrame(RadialGeometry.frame(center:center,screen:screen?.visibleFrame ?? CGRect(x:0,y:0,width:1440,height:900)),display:false)
        state.appeared = false; panel.orderFrontRegardless()
        if pinned { pin() }
        DispatchQueue.main.async { [weak self] in self?.state.appeared = true }
        EventReceipt.record("menu_shown",["source":state.entry.rawValue, "count":urls.count,"tools":tools])
    }
    func pin() {
        dismissGeneration += 1; state.pinned = true; state.dragHover = false
        NSApp.activate(ignoringOtherApps:true); panel.makeKey(); panel.makeFirstResponder(dropView)
        EventReceipt.record("menu_staged",["source":state.entry.rawValue,"count":state.urls.count])
    }
    func scheduleDragDismissal() {
        let generation = dismissGeneration
        DispatchQueue.main.asyncAfter(deadline:.now()+0.8) { [weak self] in
            guard let self, self.dismissGeneration == generation, !self.state.pinned, !self.state.dragHover, self.state.entry == .desktopButton else { return }
            self.hide()
        }
    }
    func update(at point:CGPoint,option:Bool) {
        let local = CGPoint(x:point.x-panel.frame.minX,y:panel.frame.maxY-point.y)
        state.update(point:local,option:option)
    }
    func hide() { dismissGeneration += 1; state.appeared = false; panel.orderOut(nil); state.selected = nil; state.dragHover = false }
    func key(_ event:NSEvent) {
        if event.type == .flagsChanged { if state.entry == .systemDrag { state.tools = state.latchedTools || event.modifierFlags.contains(.option); state.selected = nil }; return }
        switch event.keyCode {
        case 53: hide()
        case 48: state.setMode(tools:!state.tools)
        case 123,126: state.selected = ((state.selected ?? 0)-1+state.actions.count) % max(1,state.actions.count)
        case 124,125: state.selected = ((state.selected ?? -1)+1) % max(1,state.actions.count)
        case 36,76:
            if let action = state.action { let urls = state.urls; hide(); onAction?(urls,action) }
        default: break
        }
    }
}

@MainActor
final class DesktopDragMonitor {
    let radial: RadialController
    private var global: Any?
    private var local: Any?
    private var polling: Timer?
    private var session = DragSessionGate(baseline: NSPasteboard(name:.drag).changeCount)
    private var dragActive = false
    private var ownMouseDown = false
    private var eventRecorded = false
    private var generation = 0
    var enabled = true
    var isInstalled:Bool { global != nil && local != nil }
    init(radial:RadialController) { self.radial = radial }
    func start() {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown,.leftMouseDragged,.leftMouseUp]
        global = NSEvent.addGlobalMonitorForEvents(matching:mask) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event,local:false) }
        }
        local = NSEvent.addLocalMonitorForEvents(matching:mask.union([.keyDown])) { [weak self] event in
            if event.type == .keyDown && event.keyCode == 53 && self?.radial.isVisible == true && self?.radial.state.entry == .systemDrag { self?.cancel(); return nil }
            self?.handle(event,local:true); return event
        }
        // Finder's native drag session can omit monitor notifications. Poll the current
        // button/pasteboard state too; a fresh drag pasteboard is required to activate.
        let timer = Timer(timeInterval:0.05,repeats:true) { [weak self] _ in MainActor.assumeIsolated { self?.tick() } }
        timer.tolerance = 0.01
        polling = timer; RunLoop.main.add(timer,forMode:.common)
    }
    func handle(_ event:NSEvent,local:Bool) {
        switch event.type {
        case .leftMouseDown:
            ownMouseDown = local
            eventRecorded = false
        case .leftMouseDragged:
            if !eventRecorded {
                eventRecorded = true
                EventReceipt.record("mouse_drag_observed",["local":local,"enabled":enabled,"shift":event.modifierFlags.contains(.shift)])
            }
            tick()
        case .leftMouseUp:
            tick()
        default: break
        }
    }
    func tick() {
        let board = NSPasteboard(name:.drag)
        let down = NSEvent.pressedMouseButtons & 1 != 0
        guard down else {
            _ = session.observe(changeCount:board.changeCount,leftDown:false,ownWindow:false)
            ownMouseDown = false; eventRecorded = false
            if dragActive { endMonitoring() }
            return
        }
        guard enabled, !(radial.isVisible && (radial.state.pinned || radial.state.entry != .systemDrag)), session.observe(changeCount:board.changeCount,leftDown:true,ownWindow:ownMouseDown) else { return }
        let files = DragFiles.read(board)
        guard !files.isEmpty else { return }
        if !dragActive {
            dragActive = true; generation += 1
            EventReceipt.record("file_drag_detected",["count":files.count,"pasteboard_types":(board.types ?? []).map(\.rawValue),"shift":NSEvent.modifierFlags.contains(.shift),"option":NSEvent.modifierFlags.contains(.option)])
        }
        if CGEventSource.keyState(.combinedSessionState,key:53) { cancel(); return }
        let flags = NSEvent.modifierFlags
        guard flags.contains(.shift) else { if radial.isVisible && !radial.state.pinned { radial.hide() }; return }
        if !radial.isVisible { radial.show(urls:files,at:NSEvent.mouseLocation,tools:flags.contains(.option)) }
        radial.update(at:NSEvent.mouseLocation,option:flags.contains(.option))
    }
    func cancel() { session.consume(); endMonitoring(); radial.hide() }
    func didPerform() { session.consume(); endMonitoring() }
    func endMonitoring() {
        dragActive = false
        let id = generation
        // NSDraggingDestination owns execution. Releasing the button only hides the menu.
        DispatchQueue.main.asyncAfter(deadline:.now()+0.18) { [weak self] in
            guard let self, !self.dragActive, self.generation == id, !self.radial.state.pinned, self.radial.state.entry == .systemDrag else { return }
            self.radial.hide()
        }
    }
}

enum DragFiles {
    static func read(_ board:NSPasteboard) -> [URL] {
        var urls = board.readObjects(forClasses:[NSURL.self],options:[.urlReadingFileURLsOnly:true]) as? [URL] ?? []
        if let paths = board.propertyList(forType:NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            urls.append(contentsOf:paths.map { URL(fileURLWithPath:$0) })
        }
        var seen = Set<String>()
        return urls.filter { $0.isFileURL && FileCatalog.kind($0) != .unsupported && seen.insert($0.standardizedFileURL.path).inserted }
    }
}

struct DragSessionGate {
    private var baseline:Int
    private var consumed = false
    init(baseline:Int) { self.baseline = baseline }
    mutating func observe(changeCount:Int,leftDown:Bool,ownWindow:Bool) -> Bool {
        if !leftDown { baseline = changeCount; consumed = false; return false }
        return !consumed && !ownWindow && changeCount != baseline
    }
    mutating func consume() { consumed = true }
}

enum EventReceipt {
    static let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/CitrusLocal/events.jsonl")
    static func record(_ event:String,_ fields:[String:Any] = [:]) {
        var value = fields; value["event"] = event; value["time"] = ISO8601DateFormatter().string(from:Date())
        guard let data = try? JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]) else { return }
        try? FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
        if !FileManager.default.fileExists(atPath:url.path) { _ = FileManager.default.createFile(atPath:url.path,contents:nil) }
        if let handle = try? FileHandle(forWritingTo:url) { defer { try? handle.close() }; _ = try? handle.seekToEnd(); try? handle.write(contentsOf:data+Data([10])) }
    }
}
