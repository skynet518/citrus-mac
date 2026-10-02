import AppKit
import SwiftUI
import PDFKit

@main
struct CitrusMain {
    @MainActor static func main() {
        if let i = CommandLine.arguments.firstIndex(of:"--verify"), CommandLine.arguments.count > i+1 {
            do { try Verification.run(directory:URL(fileURLWithPath:CommandLine.arguments[i+1]),failureProbe:CommandLine.arguments.contains("--failure-probe")); exit(0) }
            catch { fputs("\(error.localizedDescription)\n",stderr); exit(1) }
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = CitrusDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class CitrusDelegate:NSObject,NSApplicationDelegate,NSWindowDelegate {
    let radial = RadialController()
    var monitor:DesktopDragMonitor!
    var status:NSStatusItem!
    var welcome:NSWindow?
    var practice:PracticeState?
    var practiceWindow:NSWindow?
    var editors:[NSWindow] = []
    let toastState = ToastState()
    var toast:NSPanel?
    var workTask:Task<Void,Never>?
    func applicationDidFinishLaunching(_ notification:Notification) {
        let mainMenu = NSMenu(), appMenu = NSMenu()
        appMenu.addItem(withTitle:"退出橘子",action:#selector(quit),keyEquivalent:"q").target = self
        let item = NSMenuItem(); item.submenu = appMenu; mainMenu.addItem(item); NSApp.mainMenu = mainMenu
        status = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
        status.length = 28
        status.button?.image = CitrusStatusIcon.make()
        status.button?.toolTip = "橘子 · 本地文件工具"
        let menu = NSMenu()
        for (title,selector) in [("选择文件…",#selector(choose)),("体验示例",#selector(demo)),("使用方法",#selector(showWelcome)),("压缩设置…",#selector(settings))] {
            let item = menu.addItem(withTitle:title,action:selector,keyEquivalent:""); item.target = self
        }
        menu.addItem(.separator())
        let pause = menu.addItem(withTitle:"暂停 Shift 拖拽",action:#selector(toggleMonitor(_:)),keyEquivalent:""); pause.target = self
        menu.addItem(.separator()); menu.addItem(withTitle:"退出橘子",action:#selector(quit),keyEquivalent:"q").target = self
        status.menu = menu
        monitor = DesktopDragMonitor(radial:radial); monitor.start()
        radial.onAction = { [weak self] urls,action in self?.monitor.didPerform(); self?.perform(urls,action:action) }
        EventReceipt.record("app_started",["version":"1.0.1-preview","mouse_monitors_installed":monitor.isInstalled,"drag_detection":"fresh-pasteboard-poll-with-mouse-monitors"])
        if !CommandLine.arguments.contains("--background") { showWelcome() }
        if let n = CommandLine.arguments.firstIndex(of:"--open"), CommandLine.arguments.count > n+1 {
            DispatchQueue.main.async { self.radial.show(urls:[URL(fileURLWithPath:CommandLine.arguments[n+1])],at:NSEvent.mouseLocation,tools:false,pinned:true) }
        }
    }
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows flag:Bool) -> Bool { if !flag { showWelcome() }; return true }
    func application(_ sender:NSApplication,openFiles filenames:[String]) {
        let urls = filenames.map { URL(fileURLWithPath:$0) }.filter { FileCatalog.kind($0) != .unsupported }
        radial.show(urls:urls,at:NSEvent.mouseLocation,tools:false,pinned:true); sender.reply(toOpenOrPrint:.success)
    }
    func makeWindow<V:View>(_ view:V,title:String) -> NSWindow {
        let host = NSHostingView(rootView:view)
        host.safeAreaRegions = []
        let window = NSWindow(contentRect:CGRect(origin:.zero,size:host.fittingSize),styleMask:[.titled,.closable,.fullSizeContentView],backing:.buffered,defer:false)
        window.title = title; window.titleVisibility = .hidden; window.titlebarAppearsTransparent = true
        window.isOpaque = false; window.backgroundColor = .clear; window.isReleasedWhenClosed = false; window.level = .floating
        window.appearance = NSAppearance(named:.aqua)
        window.standardWindowButton(.closeButton)?.isHidden = true; window.standardWindowButton(.miniaturizeButton)?.isHidden = true; window.standardWindowButton(.zoomButton)?.isHidden = true
        window.contentView = host; window.delegate = self
        window.setFrame(CGRect(origin:window.frame.origin,size:host.fittingSize),display:false); window.center(); NSApp.activate(ignoringOtherApps:true); window.makeKeyAndOrderFront(nil)
        return window
    }
    @objc func showWelcome() {
        if let welcome { NSApp.activate(ignoringOtherApps:true); welcome.makeKeyAndOrderFront(nil); return }
        welcome = makeWindow(WelcomeView(onChoose:{ [weak self] in self?.choose() },onDemo:{ [weak self] in self?.demo() },onClose:{ [weak self] in self?.welcome?.close() }),title:"橘子 · 使用方法")
    }
    @objc func choose() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = true
        panel.title = "选择要转换的文件"; panel.prompt = "打开圆形菜单"
        NSApp.activate(ignoringOtherApps:true)
        if panel.runModal() == .OK {
            let urls = panel.urls.filter { FileCatalog.kind($0) != .unsupported }
            if urls.isEmpty { failure("所选文件格式暂不支持。"); return }
            welcome?.close(); radial.show(urls:urls,at:NSEvent.mouseLocation,tools:false,pinned:true)
        }
    }
    @objc func demo() {
        do {
            let folder = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("CitrusLocal/体验文件")
            try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            let pdf = folder.appendingPathComponent("Page 001.pdf")
            if !FileManager.default.fileExists(atPath:pdf.path) { try FileEngine.pdfData(FileEngine.textPages("橘子文件工具\n\n这是一个可以拖动、转换、裁剪的本地示例。\n\n1. 按住 Shift 拖动 PDF，松手转换 JPG。\n2. 按住 Shift + Option 拖动 JPG，选择 Crop。\n3. 拖动裁剪边框，然后点击 Apply。\n4. 再次拖动结果，选择 Add BG。\n5. 调整背景、圆角和阴影，保存新图片。\n\n所有文件均保存在此文件夹，原文件会保留。"),dpi:150).write(to:pdf,options:.withoutOverwriting) }
            welcome?.close()
            if let practiceWindow { practiceWindow.makeKeyAndOrderFront(nil); return }
            let state = PracticeState(files:[pdf]); practice = state
            practiceWindow = makeWindow(PracticeView(state:state,onClose:{ [weak self] in self?.practiceWindow?.close() },onDrop:{ [weak self] urls,action in self?.perform(urls,action:action) }),title:"橘子 · 交互演练")
        } catch { failure(error.localizedDescription) }
    }
    @objc func settings() {
        let alert = NSAlert(); alert.messageText = "压缩设置"; alert.informativeText = "选择默认压缩强度和图片最长边。"
        let quality = NSPopUpButton(frame:CGRect(x:0,y:45,width:250,height:25)); quality.addItems(withTitles:["Balanced","Strong"]); quality.selectItem(at:UserDefaults.standard.bool(forKey:"strongCompression") ? 1 : 0)
        let size = NSPopUpButton(frame:CGRect(x:0,y:5,width:250,height:25)); size.addItems(withTitles:["保留原尺寸","2560 px","1920 px","1280 px"])
        let sizes = [0,2560,1920,1280]; size.selectItem(at:sizes.firstIndex(of:UserDefaults.standard.integer(forKey:"compressionMaxSide")) ?? 0)
        let view = NSView(frame:CGRect(x:0,y:0,width:250,height:80)); view.addSubview(quality); view.addSubview(size); alert.accessoryView = view
        alert.addButton(withTitle:"保存"); alert.addButton(withTitle:"取消")
        if alert.runModal() == .alertFirstButtonReturn { UserDefaults.standard.set(quality.indexOfSelectedItem == 1,forKey:"strongCompression"); UserDefaults.standard.set(sizes[size.indexOfSelectedItem],forKey:"compressionMaxSide") }
    }
    @objc func toggleMonitor(_ sender:NSMenuItem) { monitor.enabled.toggle(); if !monitor.enabled { monitor.cancel() }; sender.title = monitor.enabled ? "暂停 Shift 拖拽" : "恢复 Shift 拖拽" }
    @objc func quit() { NSApp.terminate(nil) }
    func windowWillClose(_ notification:Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if welcome === window { welcome = nil }
        if practiceWindow === window { practiceWindow = nil; practice = nil }
        editors.removeAll { $0 === window }
    }
    func perform(_ urls:[URL],action:RadialAction) {
        EventReceipt.record("action_requested",["action":action.title,"count":urls.count])
        switch action {
        case .convert(let format): runJob("正在转换为 \(format.uppercased())…") { try FileEngine.convert(urls,format:format) }
        case .tool(let tool):
            if tool == .metadata && urls.count > 1 {
                runJob("正在移除元数据…") {
                    try urls.map { source in
                        if FileCatalog.kind(source) == .image { return try FileEngine.saveImage(FileEngine.loadImage(source),source:source,suffix:" Metadata") }
                        if FileCatalog.kind(source) == .pdf {
                            guard let doc = PDFDocument(url:source) else { throw CitrusError.failed("PDF 无法打开。") }
                            doc.documentAttributes = [:]
                            guard let data = doc.dataRepresentation() else { throw CitrusError.failed("PDF 保存失败。") }
                            let out = OutputFiles.available(source:source,suffix:" Metadata",ext:"pdf"); try data.write(to:out,options:.withoutOverwriting); return out
                        }
                        let out = OutputFiles.available(source:source,suffix:" Metadata",ext:source.pathExtension)
                        try MediaEngine.tool(.metadata,source:source,destination:out); return out
                    }
                }
                return
            }
            if [.crop,.background,.edit,.annotate,.redact].contains(tool) || (tool == .metadata && urls.first.map(FileCatalog.kind) == .image) {
                guard urls.count == 1 else { failure("此编辑工具每次处理一张图片，请选择单个文件。"); return }
                openImageEditor(urls[0],tool:tool)
            } else {
                switch tool {
                case .compress:
                    runJob("正在压缩…") { try FileEngine.compress(urls,strong:UserDefaults.standard.bool(forKey:"strongCompression"),maxSide:UserDefaults.standard.integer(forKey:"compressionMaxSide")) }
                case .splitPDF: runJob("正在拆分 PDF…") { try urls.flatMap(FileEngine.splitPDF) }
                case .mergePDF:
                    if urls.count < 2 { failure("合并需要同时拖入至少两个 PDF。"); return }
                    runJob("正在合并 PDF…") { try FileEngine.mergePDF(urls) }
                case .createPDF:
                    runJob("正在创建 PDF…") {
                        let out = OutputFiles.available(source:urls[0],suffix:" Combined",ext:"pdf")
                        try FileEngine.pdfData(urls.map { try FileEngine.loadImage($0) }).write(to:out,options:.withoutOverwriting); return [out]
                    }
                case .extractText: runJob("正在提取文字…") { try FileEngine.convert(urls,format:"txt") }
                case .extractArchive: runJob("正在解压…") { try urls.map(ArchiveEngine.extract) }
                case .mute,.normalize: runJob("正在处理…") {
                    try urls.map { source in
                        let out = OutputFiles.available(source:source,suffix:" \(tool.name)",ext:tool == .normalize ? "m4a" : "mp4")
                        try MediaEngine.tool(tool,source:source,destination:out); return out
                    }
                }
                default: openUtilityEditor(urls,tool:tool)
                }
            }
        }
    }
    func openImageEditor(_ source:URL,tool:Tool) {
        beginToast("正在打开 \(tool.name)…")
        Task {
            do {
                let image = try await Task.detached(priority:.userInitiated) { try FileEngine.loadImage(source) }.value
                toast?.orderOut(nil)
                let model = ImageEditorModel(tool:tool,source:source,image:image)
                let ref = WindowReference()
                let window = makeWindow(ImageEditorView(model:model,onClose:{ ref.window?.close() },onSaved:{ [weak self] output in ref.window?.close(); self?.success([output]) }),title:tool.name)
                ref.window = window; editors.append(window)
                EventReceipt.record("editor_opened",["tool":tool.title,"width":image.width,"height":image.height])
            } catch { failure(error.localizedDescription) }
        }
    }
    func openUtilityEditor(_ urls:[URL],tool:Tool) {
        let model = UtilityModel(tool:tool,sources:urls)
        let ref = WindowReference()
        let window = makeWindow(UtilityEditorView(model:model,onClose:{ ref.window?.close() },onSaved:{ [weak self] outputs in ref.window?.close(); self?.success(outputs) }),title:tool.name)
        ref.window = window; editors.append(window)
    }
    func runJob(_ title:String,work:@escaping () throws -> [URL]) {
        guard workTask == nil else { failure("上一个任务正在处理中，请稍候。"); return }
        beginToast(title)
        workTask = Task {
            do { let outputs = try await Task.detached(priority:.userInitiated,operation:work).value; success(outputs) }
            catch CitrusError.partial(let outputs,let errors) {
                toastState.title = "已生成 \(outputs.count) 个文件，\(errors.count) 个未完成"
                toastState.detail = errors.joined(separator:"\n"); toastState.processing = false; toastState.failed = true; toastState.outputs = outputs
                showToast(); EventReceipt.record("partial_result",["paths":outputs.map(\.path),"errors":errors])
            }
            catch { failure(error.localizedDescription) }
            workTask = nil
        }
    }
    func beginToast(_ title:String) {
        toastState.title = title; toastState.detail = ""; toastState.processing = true; toastState.failed = false; toastState.outputs = []
        showToast()
    }
    func showToast() {
        if toast == nil {
            let panel = NSPanel(contentRect:CGRect(x:0,y:0,width:340,height:140),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
            panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true; panel.level = .floating; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
            panel.contentView = NSHostingView(rootView:ToastView(state:toastState,onClose:{ [weak self] in self?.toast?.orderOut(nil) }))
            toast = panel
        }
        if let host = toast?.contentView as? NSHostingView<ToastView> { toast?.setContentSize(host.fittingSize) }
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let bounds = screen?.visibleFrame, let toast { toast.setFrameOrigin(CGPoint(x:bounds.maxX-toast.frame.width-24,y:bounds.maxY-toast.frame.height-24)); toast.orderFrontRegardless() }
    }
    func success(_ outputs:[URL]) {
        toastState.title = "已生成 \(outputs.count) 个文件"; toastState.detail = outputs.map(\.lastPathComponent).joined(separator:"、"); toastState.processing = false; toastState.failed = false; toastState.outputs = outputs
        showToast(); NSSound(named:"Pop")?.play()
        EventReceipt.record("output_created",["paths":outputs.map(\.path),"count":outputs.count])
        if let practice { practice.files.append(contentsOf:outputs.filter { !practice.files.contains($0) }); if let last = outputs.last { practice.radial.urls = [last] } }
    }
    func failure(_ message:String) {
        toastState.title = "处理未完成"; toastState.detail = message; toastState.processing = false; toastState.failed = true; toastState.outputs = []
        showToast(); EventReceipt.record("operation_failed",["message":message])
    }
}
