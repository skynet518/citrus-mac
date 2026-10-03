import AppKit
import SwiftUI
import Observation
import ImageIO

@MainActor @Observable
final class ImageEditorModel {
    let tool:Tool
    let source:URL
    let image:CGImage
    let thumbnail:CGImage
    var cropRect = CGRect(x:0,y:0,width:1,height:1)
    var cropRatio = 0.0
    var widthText = ""
    var heightText = ""
    var style = BackgroundStyle()
    var edit = EditSettings()
    var preview:CGImage?
    var marks:[PaintMark] = []
    var paintKind:PaintMark.Kind = .pen
    var paintColor = Color.red
    var paintWidth = 12.0
    var paintText = "备注"
    var removeAllMetadata = true
    var removeLocation = true
    var author = ""
    var caption = ""
    var properties:[CFString:Any] = [:]
    var busy = false
    var error:String?
    private var previewTask:Task<Void,Never>?
    private var generation = 0
    init(tool:Tool,source:URL,image:CGImage) {
        self.tool = tool; self.source = source; self.image = image
        thumbnail = (try? FileEngine.resized(image,maxSide:1200)) ?? image
        properties = FileEngine.metadata(source)
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString:Any] ?? [:]
        let iptc = properties[kCGImagePropertyIPTCDictionary] as? [CFString:Any] ?? [:]
        let png = properties[kCGImagePropertyPNGDictionary] as? [CFString:Any] ?? [:]
        author = tiff[kCGImagePropertyTIFFArtist] as? String ?? (iptc[kCGImagePropertyIPTCByline] as? [String])?.first ?? png[kCGImagePropertyPNGAuthor] as? String ?? ""
        caption = tiff[kCGImagePropertyTIFFImageDescription] as? String ?? iptc[kCGImagePropertyIPTCCaptionAbstract] as? String ?? png[kCGImagePropertyPNGDescription] as? String ?? ""
        if tool == .redact { paintKind = .redact; paintColor = .black }
        updateCropFields(); refreshPreview()
    }
    func updateCropFields() {
        let pixels = ImageRendering.cropBounds(image,normalized:cropRect)
        widthText = String(Int(pixels.width)); heightText = String(Int(pixels.height))
    }
    func applyDimensions() {
        guard let width = Double(widthText), let height = Double(heightText), width > 0,height > 0 else { return }
        var w = min(1,width/Double(image.width)), h = min(1,height/Double(image.height))
        if cropRatio > 0 { h = w*Double(image.width)/Double(image.height)/cropRatio; if h > 1 { h = 1; w = h*Double(image.height)/Double(image.width)*cropRatio } }
        cropRect = CGRect(x:min(cropRect.minX,1-w),y:min(cropRect.minY,1-h),width:w,height:h); updateCropFields()
    }
    func setRatio() {
        guard cropRatio > 0 else { return }
        var w = cropRect.width, h = w*Double(image.width)/Double(image.height)/cropRatio
        if h > 1 { h = 1; w = h*Double(image.height)/Double(image.width)*cropRatio }
        cropRect = CGRect(x:min(cropRect.minX,1-w),y:min(cropRect.minY,1-h),width:w,height:h); updateCropFields()
    }
    func reset() {
        cropRect = CGRect(x:0,y:0,width:1,height:1); cropRatio = 0; updateCropFields()
        style = BackgroundStyle(); edit = EditSettings(); marks = []; error = nil; refreshPreview()
    }
    func refreshPreview() {
        generation += 1; let id = generation
        previewTask?.cancel()
        let image = self.image, thumb = self.thumbnail, style = self.style, edit = self.edit, tool = self.tool
        previewTask = Task {
            try? await Task.sleep(nanoseconds:50_000_000)
            guard !Task.isCancelled else { return }
            let result = await Task.detached(priority:.userInitiated) { () -> CGImage? in
                if tool == .background { return try? ImageRendering.background(image,style:style,previewMax:960) }
                if tool == .edit { return try? ImageRendering.edited(thumb,settings:edit) }
                return thumb
            }.value
            guard !Task.isCancelled, id == generation else { return }
            preview = result
        }
    }
    func renderAndSave() async throws -> URL {
        let image = self.image, source = self.source, tool = self.tool, crop = self.cropRect, style = self.style,
            edit = self.edit, marks = self.marks, clear = self.removeAllMetadata, removeLocation = self.removeLocation,
            author = self.author, caption = self.caption, properties = self.properties
        return try await Task.detached(priority:.userInitiated) {
            let output:CGImage
            var suffix = "", metadata:[CFString:Any] = [:]
            switch tool {
            case .crop: output = try ImageRendering.crop(image,normalized:crop); suffix = " Cropped"
            case .background: output = try ImageRendering.background(image,style:style); suffix = " BG"
            case .edit: output = try ImageRendering.edited(image,settings:edit); suffix = " Edited"
            case .annotate: output = try ImageRendering.painted(image,marks:marks); suffix = " Annotated"
            case .redact: output = try ImageRendering.painted(image,marks:marks); suffix = " Redacted"
            case .metadata:
                output = image; suffix = " Metadata"
                metadata = FileEngine.editedMetadata(properties,clear:clear,removeLocation:removeLocation,author:author,caption:caption)
            default: throw CitrusError.failed("此工具不是图片编辑器。")
            }
            let metadataFormat = tool == .metadata && ["webp","bmp","avif"].contains(source.pathExtension.lowercased()) && (!author.isEmpty || !caption.isEmpty) ? "png" : nil
            return try FileEngine.saveImage(output,source:source,suffix:suffix,format:metadataFormat,properties:metadata)
        }.value
    }
}

struct EditorHeader:View {
    let title:String
    let onClose:() -> Void
    var body:some View {
        HStack {
            Button(action:onClose) { Image(systemName:"xmark").font(.system(size:11,weight:.medium)).frame(width:28,height:28).background(CitrusTheme.surface,in:Circle()) }.buttonStyle(.plain).accessibilityLabel("关闭")
            Spacer(); Text(title).font(.system(size:15,weight:.semibold)); Spacer(); Color.clear.frame(width:28,height:28)
        }.padding(.horizontal,16).padding(.vertical,14)
    }
}

struct ImageEditorView:View {
    @Bindable var model:ImageEditorModel
    let onClose:() -> Void
    let onSaved:(URL) -> Void
    var body:some View {
        VStack(spacing:0) {
            EditorHeader(title:model.tool.name,onClose:onClose)
            Divider().opacity(0.35)
            VStack(spacing:16) {
                editorContent
                if let error = model.error { Text(error).font(.caption).foregroundStyle(.red).fixedSize(horizontal:false,vertical:true) }
            }.padding(20)
            Divider().opacity(0.35)
            HStack {
                Button("Reset") { model.reset() }.buttonStyle(.borderless)
                Spacer()
                if model.busy { ProgressView().controlSize(.small) }
                Button(model.tool == .background ? "Save with Background" : (model.tool == .crop ? "Apply" : "Save Copy")) { save() }
                    .buttonStyle(.borderedProminent).tint(CitrusTheme.orange).keyboardShortcut(.defaultAction).disabled(model.busy)
            }.padding(16)
        }
        .foregroundStyle(CitrusTheme.ink).tint(CitrusTheme.orange)
        .background(WarmGlass())
        .onChange(of:model.cropRect) { _,_ in model.updateCropFields() }
        .onChange(of:model.cropRatio) { _,_ in model.setRatio() }
        .onChange(of:model.style) { _,_ in model.refreshPreview() }
        .onChange(of:model.edit) { _,_ in model.refreshPreview() }
        .frame(width:490)
    }
    @ViewBuilder var editorContent:some View {
        switch model.tool {
        case .crop: cropContent
        case .background: BackgroundControls(model:model)
        case .edit: editContent
        case .annotate,.redact: paintContent
        case .metadata: metadataContent
        default: EmptyView()
        }
    }
    var cropContent:some View {
        VStack(spacing:16) {
            CropSurface(image:model.image,rect:$model.cropRect,ratio:model.cropRatio).frame(height:420)
            HStack { Text("Aspect ratio").font(.caption); Spacer(); Picker("Aspect ratio",selection:$model.cropRatio) {
                Text("Free").tag(0.0); Text("1:1").tag(1.0); Text("16:9").tag(16.0/9); Text("9:16").tag(9.0/16); Text("4:3").tag(4.0/3); Text("3:4").tag(3.0/4)
            }.pickerStyle(.segmented).labelsHidden().frame(width:330) }
            HStack(spacing:8) {
                Text("W").font(.caption)
                TextField("Width",text:$model.widthText).frame(width:72).onSubmit { model.applyDimensions() }.accessibilityLabel("裁剪宽度")
                Text("H").font(.caption)
                TextField("Height",text:$model.heightText).frame(width:72).onSubmit { model.applyDimensions() }.accessibilityLabel("裁剪高度")
                Text("px").font(.caption); Spacer()
            }.textFieldStyle(.roundedBorder)
        }
    }
    var editContent:some View {
        VStack(spacing:12) {
            PreviewImage(image:model.preview ?? model.thumbnail).frame(height:310)
            ValueSlider(title:"Exposure",value:$model.edit.exposure,range:-2...2,unit:"EV")
            ValueSlider(title:"Brightness",value:$model.edit.brightness,range:-0.3...0.3,unit:"")
            ValueSlider(title:"Contrast",value:$model.edit.contrast,range:0.3...2,unit:"")
            ValueSlider(title:"Saturation",value:$model.edit.saturation,range:0...2,unit:"")
            ValueSlider(title:"Warmth",value:$model.edit.warmth,range:3000...10000,unit:"K")
            ValueSlider(title:"Sharpness",value:$model.edit.sharpness,range:0...2,unit:"")
            HStack {
                Button { model.edit.rotation = (model.edit.rotation+1)%4 } label:{ Label("Rotate",systemImage:"rotate.right") }
                Toggle("Flip",isOn:$model.edit.flip).toggleStyle(.button)
                Spacer()
            }.controlSize(.small)
        }
    }
    var paintContent:some View {
        VStack(spacing:14) {
            PaintSurface(image:model.image,marks:$model.marks,kind:model.paintKind,color:NSColor(model.paintColor),lineWidth:model.paintWidth,text:model.paintText).frame(height:390)
            Picker("Tool",selection:$model.paintKind) {
                if model.tool == .redact {
                    Text("Block").tag(PaintMark.Kind.redact); Text("Blur").tag(PaintMark.Kind.blur); Text("Pixelate").tag(PaintMark.Kind.pixelate)
                } else {
                    Text("Pen").tag(PaintMark.Kind.pen); Text("Rectangle").tag(PaintMark.Kind.rectangle); Text("Arrow").tag(PaintMark.Kind.arrow); Text("Text").tag(PaintMark.Kind.text)
                }
            }.pickerStyle(.segmented).labelsHidden()
            HStack {
                ColorPicker("Color",selection:$model.paintColor,supportsOpacity:false)
                Text("Width").font(.caption); Slider(value:$model.paintWidth,in:2...64).frame(width:140)
                Button("Undo") { if !model.marks.isEmpty { model.marks.removeLast() } }.disabled(model.marks.isEmpty)
            }.controlSize(.small)
            if model.paintKind == .text { TextField("Text",text:$model.paintText).textFieldStyle(.roundedBorder) }
            Text(model.tool == .redact ? "拖动覆盖需要隐藏的区域。保存为一张新的图片。" : "在图片上拖动添加标注，原图会保留。") .font(.caption).foregroundStyle(.secondary)
        }
    }
    var metadataContent:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack {
                PreviewImage(image:model.thumbnail).frame(width:100,height:90)
                VStack(alignment:.leading,spacing:6) { Text(model.source.lastPathComponent).font(.headline).lineLimit(2); Text("\(model.image.width) × \(model.image.height) px").font(.caption) }
                Spacer()
            }
            ScrollView {
                VStack(alignment:.leading,spacing:6) {
                    ForEach(metadataRows(),id:\.self) { line in Text(line).font(.system(size:11,design:.monospaced)).frame(maxWidth:.infinity,alignment:.leading).textSelection(.enabled) }
                }
            }.frame(height:260).padding(10).background(CitrusTheme.surface,in:RoundedRectangle(cornerRadius:12))
            Toggle("Remove existing metadata",isOn:$model.removeAllMetadata)
            Toggle("Remove location",isOn:$model.removeLocation)
            TextField("Author",text:$model.author).textFieldStyle(.roundedBorder)
            TextField("Description",text:$model.caption).textFieldStyle(.roundedBorder)
            if ["webp","bmp","avif"].contains(model.source.pathExtension.lowercased()) { Text("填写作者或描述时，元数据副本会保存为 PNG。") .font(.caption).foregroundStyle(.secondary) }
        }
    }
    func metadataRows() -> [String] {
        model.properties.keys.sorted(by:{ "\($0)" < "\($1)" }).map { "\($0): \(model.properties[$0]!)" }
    }
    func save() {
        model.busy = true; model.error = nil
        if model.tool == .crop { model.applyDimensions() }
        Task {
            do { let output = try await model.renderAndSave(); model.busy = false; onSaved(output) }
            catch { model.busy = false; model.error = error.localizedDescription }
        }
    }
}

struct PreviewImage:View {
    let image:CGImage?
    var body:some View {
        Group {
            if let image { Image(nsImage:NSImage(cgImage:image,size:.zero)).resizable().interpolation(.high).scaledToFit() }
            else { ProgressView() }
        }.frame(maxWidth:.infinity,maxHeight:.infinity)
    }
}

struct ValueSlider:View {
    let title:String
    @Binding var value:Double
    let range:ClosedRange<Double>
    let unit:String
    var body:some View {
        HStack(spacing:10) {
            Text(title).font(.system(size:12)).frame(width:76,alignment:.leading)
            Slider(value:$value,in:range).accessibilityLabel(title)
            Text(range.upperBound > 5 ? "\(Int(value)) \(unit)" : String(format:"%.2f %@",value,unit)).font(.system(size:11,design:.monospaced)).frame(width:68,alignment:.trailing)
        }
    }
}

struct BackgroundControls:View {
    @Bindable var model:ImageEditorModel
    var body:some View {
        VStack(spacing:16) {
            PreviewImage(image:model.preview).frame(height:330).clipShape(RoundedRectangle(cornerRadius:6))
            HStack(alignment:.top,spacing:14) {
                Text("Background").font(.system(size:11)).frame(width:76,alignment:.leading).padding(.top,7)
                VStack(spacing:7) {
                    HStack(spacing:5) {
                        ForEach(0..<ImageRendering.gradients.count,id:\.self) { n in
                            swatch(n) { LinearGradient(colors:ImageRendering.gradients[n].map(Color.init(nsColor:)),startPoint:.topLeading,endPoint:.bottomTrailing) }
                        }
                        Button { chooseBackground() } label:{ Image(systemName:"photo.badge.plus").font(.system(size:15)).frame(width:28,height:28) }.buttonStyle(.plain).help("选择背景图片")
                    }
                    HStack(spacing:5) {
                        ForEach(0..<ImageRendering.solidColors.count,id:\.self) { n in swatch(n+20) { Color(nsColor:ImageRendering.solidColors[n]) } }
                        ColorPicker("",selection:Binding(get:{ Color(nsColor:model.style.customColor) },set:{ model.style.customColor = NSColor($0); model.style.preset = 99 }),supportsOpacity:false).labelsHidden().frame(width:40).help("自定义背景颜色")
                    }
                }
            }
            ValueSlider(title:"Padding",value:$model.style.padding,range:0...1200,unit:"px")
            ValueSlider(title:"Corners",value:$model.style.corners,range:0...400,unit:"px")
            ValueSlider(title:"Shadow",value:$model.style.shadow,range:0...160,unit:"px")
            HStack {
                Text("Ratio").font(.system(size:11)).frame(width:76,alignment:.leading)
                Picker("Ratio",selection:$model.style.ratio) { Text("Auto").tag(0.0); Text("1:1").tag(1.0); Text("16:9").tag(16.0/9); Text("4:5").tag(4.0/5) }.pickerStyle(.segmented).labelsHidden()
            }
        }
    }
    func swatch<V:View>(_ n:Int,@ViewBuilder fill:() -> V) -> some View {
        Button { model.style.preset = n } label:{ fill().frame(width:28,height:28).clipShape(RoundedRectangle(cornerRadius:5)).overlay(RoundedRectangle(cornerRadius:5).stroke(model.style.preset == n ? CitrusTheme.orange : .white.opacity(0.3),lineWidth:model.style.preset == n ? 2.5 : 0.7)) }
        .buttonStyle(.plain).accessibilityLabel("背景预设 \(n+1)")
    }
    func chooseBackground() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.image]; panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            if let image = try? FileEngine.loadImage(url) { model.style.photo = image; model.style.preset = 100 }
        }
    }
}
