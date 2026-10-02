import AppKit
import SwiftUI
import Observation

@MainActor @Observable
final class PracticeState {
    var files:[URL]
    let radial = RadialState()
    init(files:[URL]) { self.files = files; radial.urls = Array(files.prefix(1)); radial.pinned = true; radial.appeared = true }
}

@MainActor
final class PracticeFile:NSView,NSDraggingSource {
    var url:URL!
    var onBegin:((URL) -> Void)?
    override var isFlipped:Bool { true }
    override func draw(_ dirtyRect:NSRect) {
        guard let url else { return }
        let icon = NSWorkspace.shared.icon(forFile:url.path)
        icon.draw(in:CGRect(x:(bounds.width-58)/2,y:6,width:58,height:58),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:nil)
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center; paragraph.lineBreakMode = .byTruncatingMiddle
        (url.lastPathComponent as NSString).draw(in:CGRect(x:4,y:72,width:bounds.width-8,height:34),withAttributes:[.font:NSFont.systemFont(ofSize:11,weight:.medium),.foregroundColor:NSColor.white,.paragraphStyle:paragraph])
    }
    override func mouseDown(with event:NSEvent) {}
    override func mouseDragged(with event:NSEvent) {
        guard let url else { return }
        onBegin?(url)
        let item = NSDraggingItem(pasteboardWriter:url as NSURL)
        item.setDraggingFrame(CGRect(x:(bounds.width-58)/2,y:6,width:58,height:58),contents:NSWorkspace.shared.icon(forFile:url.path))
        beginDraggingSession(with:[item],event:event,source:self)
    }
    func draggingSession(_ session:NSDraggingSession,sourceOperationMaskFor context:NSDraggingContext) -> NSDragOperation { .copy }
    func ignoreModifierKeys(for session:NSDraggingSession) -> Bool { true }
}

struct PracticeFileSurface:NSViewRepresentable {
    let url:URL
    let onBegin:(URL) -> Void
    func makeNSView(context:Context) -> PracticeFile {
        let view = PracticeFile(); view.setAccessibilityElement(true); view.setAccessibilityRole(.image); return view
    }
    func updateNSView(_ view:PracticeFile,context:Context) { view.url = url; view.onBegin = onBegin; view.setAccessibilityLabel("拖动文件 \(url.lastPathComponent)"); view.needsDisplay = true }
}

struct PracticeRadial:NSViewRepresentable {
    let state:RadialState
    let onDrop:([URL],RadialAction) -> Void
    func makeNSView(context:Context) -> RadialDropView { let view = RadialDropView(state:state); view.onPerform = onDrop; return view }
    func updateNSView(_ view:RadialDropView,context:Context) { view.onPerform = onDrop }
}

struct PracticeView:View {
    let state:PracticeState
    let onClose:() -> Void
    let onDrop:([URL],RadialAction) -> Void
    var body:some View {
        VStack(spacing:0) {
            EditorHeader(title:"交互演练",onClose:onClose).background(WarmGlass())
            HStack {
                Text("把左侧文件拖到圆形菜单，松手执行。") .font(.system(size:12))
                Spacer()
                Picker("菜单",selection:Binding(get:{ state.radial.latchedTools },set:{ state.radial.latchedTools = $0; state.radial.tools = $0; state.radial.selected = nil })) { Text("格式").tag(false); Text("工具").tag(true) }.pickerStyle(.segmented).frame(width:140)
            }.padding(16).foregroundStyle(CitrusTheme.ink).background(WarmGlass())
            HStack(spacing:36) {
                ScrollView {
                    VStack(spacing:14) {
                        ForEach(state.files,id:\.self) { url in
                            PracticeFileSurface(url:url,onBegin:{ file in state.radial.urls = [file]; state.radial.selected = nil }).frame(width:210,height:112)
                        }
                    }.padding(.vertical,30)
                }.frame(width:210,height:410)
                PracticeRadial(state:state.radial,onDrop:onDrop).frame(width:340,height:340)
            }.padding(.horizontal,32).background(LinearGradient(colors:[Color(red:1,green:0.20,blue:0.27),Color(red:1,green:0.67,blue:0.12),Color(red:0.35,green:0.36,blue:0.8)],startPoint:.topLeading,endPoint:.bottomTrailing))
            HStack {
                Text("在 Finder 或桌面使用时，按住 Shift 拖动；加按 Option 切换工具。") .font(.system(size:11)).foregroundStyle(.secondary)
                Spacer()
                Button("在 Finder 中打开") { NSWorkspace.shared.activateFileViewerSelecting(Array(state.files.prefix(1))) }.buttonStyle(.borderless).font(.caption)
            }.padding(16).background(WarmGlass())
        }.frame(width:680).tint(CitrusTheme.orange).preferredColorScheme(.light)
    }
}

@MainActor final class WindowReference { weak var window:NSWindow? }
