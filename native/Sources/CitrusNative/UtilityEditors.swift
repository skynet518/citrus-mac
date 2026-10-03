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
    let onSettings:() -> Void
    var body:some View {
        VStack(spacing:22) {
            ZStack {
                RoundedRectangle(cornerRadius:22).fill(CitrusTheme.surface).frame(width:72,height:72)
                    .overlay(RoundedRectangle(cornerRadius:22).stroke(CitrusTheme.border,lineWidth:0.5))
                Image(nsImage:CitrusStatusIcon.make()).renderingMode(.template).resizable().scaledToFit().frame(width:36,height:36).foregroundStyle(CitrusTheme.orange)
            }.padding(.top,8)
            VStack(spacing:8) { Text("橘子").font(.system(size:28,weight:.semibold)); Text("拖一下，就换好了。") .font(.system(size:15)).foregroundStyle(.secondary) }
            VStack(alignment:.leading,spacing:20) {
                instruction(symbol:"arrow.down.doc",title:"把文件拖到小橘子",detail:"桌面按钮旁会展开操作圆盘。")
                instruction(symbol:"cursorarrow.click",title:"放下文件，点击想要的操作",detail:"也可直接拖进格式扇区，松手执行。")
                instruction(symbol:"slider.horizontal.3",title:"点击「工具」，继续编辑",detail:"裁剪、背景、压缩、调色、标注和遮挡。")
            }.frame(maxWidth:.infinity,alignment:.leading).padding(20).background(CitrusTheme.surface,in:RoundedRectangle(cornerRadius:18))
            VStack(spacing:10) {
                HStack(spacing:12) {
                    Button(action:onDemo) { Text("体验示例").frame(maxWidth:.infinity) }.buttonStyle(CitrusButtonStyle())
                    Button(action:onChoose) { Text("选择文件…").frame(maxWidth:.infinity) }.buttonStyle(CitrusButtonStyle(primary:true))
                }
                Button(action:onClose) { Text("开始使用，收起窗口").frame(maxWidth:.infinity) }.buttonStyle(CitrusButtonStyle())
            }.font(.system(size:14,weight:.medium)).controlSize(.large).tint(CitrusTheme.orange)
            VStack(spacing:10) {
                Button("桌面按钮设置…",action:onSettings).buttonStyle(.plain).font(.system(size:12)).foregroundStyle(.secondary)
                Text("文件在本机处理 · 原文件始终保留").font(.system(size:11)).foregroundStyle(.secondary)
            }
        }.padding(30).frame(width:430).foregroundStyle(CitrusTheme.ink).background(WarmGlass())
    }
    func instruction(symbol:String,title:String,detail:String) -> some View {
        HStack(spacing:15) {
            Image(systemName:symbol).font(.system(size:19,weight:.regular)).foregroundStyle(CitrusTheme.orange).frame(width:38,height:38)
            VStack(alignment:.leading,spacing:5) { Text(title).font(.system(size:13,weight:.semibold)); Text(detail).font(.system(size:12)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true) }
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
        }.padding(18).frame(width:340).foregroundStyle(CitrusTheme.ink).background(WarmGlass().clipShape(RoundedRectangle(cornerRadius:18)))
    }
}
