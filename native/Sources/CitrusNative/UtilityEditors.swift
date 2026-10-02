import AppKit
import SwiftUI
import AVKit
import PDFKit
import Observation

@MainActor @Observable
final class UtilityModel {
    let tool:Tool
    let sources:[URL]
    var start = 0.0
    var end = 10.0
    var duration = 10.0
    var speed = 1.0
    var channels = 2.0
    var author = ""
    var title = ""
    var strong = UserDefaults.standard.bool(forKey:"strongCompression")
    var maxSide = UserDefaults.standard.integer(forKey:"compressionMaxSide")
    var clearMetadata = true
    var busy = false
    var error:String?
    var player:AVPlayer?
    init(tool:Tool,sources:[URL]) {
        self.tool = tool; self.sources = sources
        guard let source = sources.first else { return }
        if FileCatalog.kind(source) == .video || FileCatalog.kind(source) == .audio {
            player = AVPlayer(url:source)
            Task {
                if let time = try? await AVURLAsset(url:source).load(.duration), time.seconds.isFinite && time.seconds > 0 { duration = time.seconds; end = time.seconds }
            }
        }
        if FileCatalog.kind(source) == .pdf, let doc = PDFDocument(url:source) {
            title = doc.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String ?? ""
            author = doc.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String ?? ""
        }
    }
    func save() async throws -> [URL] {
        let sources = self.sources, tool = self.tool, strong = self.strong, maxSide = self.maxSide,
            start = self.start, end = self.end, speed = self.speed, channels = self.channels,
            clear = self.clearMetadata, author = self.author, title = self.title
        return try await Task.detached(priority:.userInitiated) {
            if tool == .compress { return try FileEngine.compress(sources,strong:strong,maxSide:maxSide) }
            return try sources.map { source in
                if FileCatalog.kind(source) == .pdf {
                    guard let doc = PDFDocument(url:source) else { throw CitrusError.failed("PDF 无法打开。") }
                    var metadata = clear ? [:] : (doc.documentAttributes ?? [:])
                    if !author.isEmpty { metadata[PDFDocumentAttribute.authorAttribute] = author }; if !title.isEmpty { metadata[PDFDocumentAttribute.titleAttribute] = title }
                    doc.documentAttributes = metadata
                    let out = OutputFiles.available(source:source,suffix:" Metadata",ext:"pdf")
                    guard let data = doc.dataRepresentation() else { throw CitrusError.failed("PDF 保存失败。") }
                    try data.write(to:out,options:.withoutOverwriting); return out
                }
                let kind = FileCatalog.kind(source)
                let ext = tool == .snapshot ? "png" : (kind == .audio ? "m4a" : "mp4")
                let out = OutputFiles.available(source:source,suffix:" \(tool.name)",ext:tool == .metadata ? source.pathExtension : ext)
                try MediaEngine.tool(tool,source:source,destination:out,value:tool == .trim || tool == .snapshot ? start : (tool == .speed ? speed : channels),end:end)
                return out
            }
        }.value
    }
}

struct UtilityEditorView:View {
    @Bindable var model:UtilityModel
    let onClose:() -> Void
    let onSaved:([URL]) -> Void
    var body:some View {
        VStack(spacing:0) {
            EditorHeader(title:model.tool.name,onClose:onClose); Divider()
            VStack(alignment:.leading,spacing:18) {
                Text(model.sources.first?.lastPathComponent ?? "").font(.headline).lineLimit(2)
                if model.sources.count > 1 { Text("共 \(model.sources.count) 个文件").font(.caption).foregroundStyle(.secondary) }
                if let player = model.player { VideoPlayer(player:player).frame(height:220) }
                controls
                if let error = model.error { Text(error).font(.caption).foregroundStyle(.red) }
            }.padding(24)
            Divider()
            HStack {
                Button("Cancel",action:onClose).buttonStyle(.borderless); Spacer()
                if model.busy { ProgressView().controlSize(.small) }
                Button("Apply") { save() }.buttonStyle(.borderedProminent).tint(CitrusTheme.orange).disabled(model.busy).keyboardShortcut(.defaultAction)
            }.padding(16)
        }.frame(width:490).background(WarmGlass()).tint(CitrusTheme.orange)
        .onDisappear { model.player?.pause() }
    }
    @ViewBuilder var controls:some View {
        switch model.tool {
        case .compress:
            Picker("Compression",selection:$model.strong) { Text("Balanced").tag(false); Text("Strong").tag(true) }.pickerStyle(.segmented)
            Picker("Resize longest edge",selection:$model.maxSide) { Text("Keep original size").tag(0); Text("2560 px").tag(2560); Text("1920 px").tag(1920); Text("1280 px").tag(1280) }
            Text("保存压缩副本，保留原文件。无法减小体积时会提示。") .font(.caption).foregroundStyle(.secondary)
        case .metadata:
            Toggle("Remove existing metadata",isOn:$model.clearMetadata)
            if model.sources.first.map(FileCatalog.kind) == .pdf {
                TextField("Title",text:$model.title); TextField("Author",text:$model.author)
            }
        case .trim:
            ValueSlider(title:"Start",value:$model.start,range:0...max(0.01,model.end-0.01),unit:"s")
                .onChange(of:model.start) { _,value in model.player?.seek(to:CMTime(seconds:value,preferredTimescale:600)) }
            ValueSlider(title:"End",value:$model.end,range:min(model.duration,model.start+0.01)...max(model.start+0.01,model.duration),unit:"s")
            HStack { TextField("Start",value:$model.start,format:.number).frame(width:90); Text("→"); TextField("End",value:$model.end,format:.number).frame(width:90); Text("seconds") }.textFieldStyle(.roundedBorder)
        case .speed:
            Picker("Speed",selection:$model.speed) { Text("0.5×").tag(0.5); Text("1×").tag(1.0); Text("1.5×").tag(1.5); Text("2×").tag(2.0) }.pickerStyle(.segmented)
        case .channels:
            Picker("Channels",selection:$model.channels) { Text("Mono").tag(1.0); Text("Stereo").tag(2.0) }.pickerStyle(.segmented)
        case .snapshot:
            ValueSlider(title:"Time",value:$model.start,range:0...max(0.1,model.duration),unit:"s").onChange(of:model.start) { _,value in model.player?.seek(to:CMTime(seconds:value,preferredTimescale:600)) }
        default: Text("保存处理后的副本。原文件会保留。") .font(.caption)
        }
    }
    func save() {
        if model.tool == .trim && (model.start < 0 || model.end <= model.start || model.end > model.duration) { model.error = "请选择有效的起止时间。"; return }
        model.busy = true; model.error = nil
        model.player?.pause()
        Task {
            do { let outputs = try await model.save(); model.busy = false; onSaved(outputs) }
            catch { model.error = error.localizedDescription; model.busy = false }
        }
    }
}

struct WelcomeView:View {
    let onChoose:() -> Void
    let onDemo:() -> Void
    let onClose:() -> Void
    var body:some View {
        VStack(spacing:24) {
            ZStack {
                Circle().fill(LinearGradient(colors:[.orange,Color(red:0.96,green:0.24,blue:0.04)],startPoint:.topLeading,endPoint:.bottomTrailing)).frame(width:68,height:68)
                Image(systemName:"arrow.triangle.2.circlepath").font(.system(size:27,weight:.semibold)).foregroundStyle(.white)
            }.padding(.top,8)
            VStack(spacing:8) { Text("橘子").font(.system(size:27,weight:.bold,design:.rounded)); Text("拖一下，就换好了。") .font(.system(size:15)).foregroundStyle(.secondary) }
            VStack(alignment:.leading,spacing:16) {
                instruction(key:"⇧",title:"按住 Shift 拖动文件",detail:"圆形菜单会出现在鼠标旁。")
                instruction(key:"↗",title:"拖进格式扇区，松手",detail:"转换结果自动放到原文件旁边。")
                instruction(key:"⌥",title:"再按 Option，切换工具",detail:"裁剪、背景、压缩、调色、标注和遮挡。")
            }.frame(maxWidth:.infinity,alignment:.leading).padding(22).background(.white.opacity(0.34),in:RoundedRectangle(cornerRadius:18))
            HStack(spacing:12) {
                Button("体验示例",action:onDemo).buttonStyle(.bordered)
                Button("选择文件…",action:onChoose).buttonStyle(.borderedProminent).tint(CitrusTheme.orange)
            }.controlSize(.large)
            Button("开始使用，收起窗口",action:onClose).buttonStyle(.borderless).font(.caption)
            Text("运行时常驻菜单栏 · 文件在本机处理") .font(.caption).foregroundStyle(.secondary)
        }.padding(30).frame(width:430).foregroundStyle(CitrusTheme.ink).background(WarmGlass())
    }
    func instruction(key:String,title:String,detail:String) -> some View {
        HStack(spacing:15) {
            Text(key).font(.system(size:23,weight:.medium)).frame(width:42,height:42).background(.white.opacity(0.5),in:RoundedRectangle(cornerRadius:11))
            VStack(alignment:.leading,spacing:4) { Text(title).font(.system(size:13,weight:.semibold)); Text(detail).font(.system(size:11)).foregroundStyle(.secondary) }
        }
    }
}

@MainActor @Observable
final class ToastState { var title = "正在处理…"; var detail = ""; var processing = true; var outputs:[URL] = []; var failed = false }
struct ToastView:View {
    let state:ToastState
    let onClose:() -> Void
    var body:some View {
        HStack(spacing:12) {
            if state.processing { ProgressView().controlSize(.small) }
            else { Image(systemName:state.failed ? "exclamationmark.circle.fill" : "checkmark.circle.fill").foregroundStyle(state.failed ? .red : .green).font(.system(size:24)) }
            VStack(alignment:.leading,spacing:4) {
                Text(state.title).font(.system(size:13,weight:.semibold))
                Text(state.detail).font(.system(size:11)).foregroundStyle(.secondary).lineLimit(state.failed ? 5 : 2)
                if !state.outputs.isEmpty {
                    Button("在 Finder 中查看") { NSWorkspace.shared.activateFileViewerSelecting(state.outputs) }.buttonStyle(.borderless).font(.caption)
                }
            }.frame(maxWidth:.infinity,alignment:.leading)
            if !state.processing { Button(action:onClose) { Image(systemName:"xmark") }.buttonStyle(.plain).accessibilityLabel("关闭提示") }
        }.padding(18).frame(width:340).foregroundStyle(CitrusTheme.ink).background(WarmGlass())
    }
}
