import AppKit
import ImageIO
import PDFKit
import Vision
import WebP
import UniformTypeIdentifiers
import CoreText
import CoreImage

enum FileEngine {
    static func context(width: Int, height: Int) throws -> CGContext {
        guard width > 0, height > 0, width <= 24000, height <= 24000, width * height <= 120_000_000,
              let c = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw CitrusError.failed("图片尺寸过大，或无法分配图像内存。")
        }
        c.interpolationQuality = .high
        return c
    }
    static func loadImage(_ url: URL, maxPixel: Int? = nil) throws -> CGImage {
        if url.pathExtension.lowercased() == "pdf" { return try pdfImages(url, firstOnly: true, dpi: maxPixel == nil ? 300 : 100)[0] }
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil) {
            let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            let originalMax = max(props?[kCGImagePropertyPixelWidth] as? Int ?? 1, props?[kCGImagePropertyPixelHeight] as? Int ?? 1)
            let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: maxPixel ?? originalMax]
            if let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) { return image }
        }
        if let image = NSImage(contentsOf: url), let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) { return cg }
        throw CitrusError.failed("无法读取 \(url.lastPathComponent)。")
    }
    static func resized(_ image: CGImage, maxSide: Int) throws -> CGImage {
        if max(image.width, image.height) <= maxSide { return image }
        let scale = Double(maxSide) / Double(max(image.width, image.height))
        let c = try context(width: max(1, Int(Double(image.width) * scale)), height: max(1, Int(Double(image.height) * scale)))
        c.draw(image, in: CGRect(x: 0, y: 0, width: c.width, height: c.height))
        return c.makeImage()!
    }
    static func imageData(_ image: CGImage, format: String, quality: Double = 0.92, properties: [CFString: Any] = [:]) throws -> Data {
        if format == "webp" {
            let width = image.width, height = image.height
            var pixels = [UInt8](repeating: 0, count: width * height * 4)
            guard let c = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw CitrusError.failed("无法编码 WebP。") }
            c.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            // libwebp accepts straight alpha; undo Core Graphics premultiplication.
            for i in stride(from: 0, to: pixels.count, by: 4) {
                let alpha = Int(pixels[i + 3])
                if alpha > 0 && alpha < 255 {
                    for j in 0..<3 { pixels[i+j] = UInt8(min(255, Int(pixels[i+j]) * 255 / alpha)) }
                }
            }
            return try pixels.withUnsafeMutableBufferPointer { buffer in
                try WebPEncoder().encode(RGBA: buffer.baseAddress!, config: .preset(.picture, quality: Float(quality * 100)),
                    originWidth: width, originHeight: height, stride: width * 4)
            }
        }
        let types = ["png": "public.png", "jpg": "public.jpeg", "jpeg": "public.jpeg", "heic": "public.heic",
                     "tiff": "public.tiff", "bmp": "com.microsoft.bmp", "avif": "public.avif"]
        guard let type = types[format] else { throw CitrusError.failed("不支持输出 \(format.uppercased())。") }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type as CFString, 1, nil) else { throw CitrusError.failed("此 Mac 不支持 \(format.uppercased()) 编码。") }
        var options = properties
        options[kCGImageDestinationLossyCompressionQuality] = quality
        var output = image
        if ["jpg", "jpeg", "bmp"].contains(format) {
            let c = try context(width: image.width, height: image.height)
            c.setFillColor(NSColor.white.cgColor); c.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
            c.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height)); output = c.makeImage()!
        }
        CGImageDestinationAddImage(destination, output, options as CFDictionary)
        guard CGImageDestinationFinalize(destination), data.length > 0 else { throw CitrusError.failed("\(format.uppercased()) 保存失败。") }
        return data as Data
    }
    static func saveImage(_ image: CGImage, source: URL, suffix: String, format: String? = nil, quality: Double = 0.92,
                          properties: [CFString: Any] = [:]) throws -> URL {
        let original = source.pathExtension.lowercased()
        let ext = format ?? (["jpg", "jpeg", "png", "webp", "heic", "avif", "bmp", "tiff"].contains(original) ? original : "png")
        let destination = OutputFiles.available(source: source, suffix: suffix, ext: ext)
        try imageData(image, format: ext, quality: quality, properties: properties).write(to: destination, options: .withoutOverwriting)
        return destination
    }
    static func pdfImages(_ url: URL, firstOnly: Bool = false, dpi: Double = 300) throws -> [CGImage] {
        guard let document = PDFDocument(url: url), !document.isLocked, document.pageCount > 0 else { throw CitrusError.failed("PDF 无法打开，或需要密码。") }
        return try (0..<(firstOnly ? 1 : document.pageCount)).map { n in
            guard let page = document.page(at: n) else { throw CitrusError.failed("PDF 第 \(n + 1) 页读取失败。") }
            let box = page.bounds(for: .mediaBox), scale = dpi / 72
            let c = try context(width: Int(ceil(box.width * scale)), height: Int(ceil(box.height * scale)))
            c.setFillColor(NSColor.white.cgColor); c.fill(CGRect(x: 0, y: 0, width: c.width, height: c.height))
            c.scaleBy(x: scale, y: scale); c.translateBy(x: -box.minX, y: -box.minY)
            page.draw(with: .mediaBox, to: c)
            return c.makeImage()!
        }
    }
    static func pdfData(_ images: [CGImage], dpi:Double = 72) throws -> Data {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data), let c = CGContext(consumer: consumer, mediaBox: nil, nil) else { throw CitrusError.failed("无法创建 PDF。") }
        for image in images {
            let rect = CGRect(x: 0, y: 0, width: Double(image.width)*72/dpi, height: Double(image.height)*72/dpi)
            c.beginPDFPage([kCGPDFContextMediaBox as String: NSData(bytes: [rect], length: MemoryLayout<CGRect>.size)] as CFDictionary)
            c.draw(image, in: rect); c.endPDFPage()
        }
        c.closePDF(); return data as Data
    }
    static func recognizeText(_ image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate; request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
    static func convert(_ sources: [URL], format: String) throws -> [URL] {
        var outputs: [URL] = []
        var failures:[String] = []
        for source in sources {
            do {
            switch FileCatalog.kind(source) {
            case .image:
                let image = try loadImage(source)
                if format == "pdf" {
                    let out = OutputFiles.available(source: source, ext: "pdf")
                    try pdfData([image]).write(to: out, options: .withoutOverwriting); outputs.append(out)
                } else if format == "docx" {
                    let out = OutputFiles.available(source: source, ext: "docx")
                    try makeDOCX(destination: out, pages: [image], text: nil); outputs.append(out)
                } else { outputs.append(try saveImage(image, source: source, suffix: "", format: format)) }
            case .pdf:
                guard let doc = PDFDocument(url: source), !doc.isLocked else { throw CitrusError.failed("PDF 无法打开。") }
                if format == "txt" {
                    let text = doc.string ?? ""
                    let recognized = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? try pdfImages(source).map(recognizeText).joined(separator: "\n\n") : text
                    let out = OutputFiles.available(source: source, ext: "txt"); try Data(recognized.utf8).write(to: out, options: .withoutOverwriting); outputs.append(out)
                } else if format == "docx" {
                    let text = doc.string ?? ""
                    let out = OutputFiles.available(source: source, ext: "docx")
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { try makeDOCX(destination: out, pages: try pdfImages(source), text: nil) }
                    else { try makeDOCX(destination: out, pages: [], text: text) }
                    outputs.append(out)
                } else {
                    let images = try pdfImages(source)
                    for (n, image) in images.enumerated() {
                        outputs.append(try saveImage(image, source: source, suffix: images.count > 1 ? " Page \(String(format: "%03d", n+1))" : "", format: format, properties: [kCGImagePropertyDPIWidth: 300, kCGImagePropertyDPIHeight: 300]))
                    }
                }
            case .audio, .video:
                let out = OutputFiles.available(source: source, ext: format)
                try MediaEngine.convert(source: source, destination: out, format: format); outputs.append(out)
            case .text, .subtitle:
                let text = try String(contentsOf: source, encoding: .utf8)
                let out = OutputFiles.available(source: source, ext: format)
                if format == "txt" { try Data(SubtitleText.plain(text).utf8).write(to: out, options: .withoutOverwriting) }
                else if ["srt", "vtt"].contains(format) { try Data(SubtitleText.convert(text, target: format).utf8).write(to: out, options: .withoutOverwriting) }
                else {
                    let images = try textPages(text)
                    if format == "pdf" { try pdfData(images,dpi:150).write(to: out, options: .withoutOverwriting) }
                    else {
                        for (n, image) in images.enumerated() { outputs.append(try saveImage(image, source: source, suffix: images.count > 1 ? " Page \(n+1)" : "", format: format)) }
                        continue
                    }
                }
                outputs.append(out)
            case .archive:
                outputs.append(try ArchiveEngine.convert(source, format: format))
            case .unsupported: throw CitrusError.failed("暂不支持 \(source.pathExtension.uppercased()) 文件。")
            }
            } catch { failures.append("\(source.lastPathComponent)：\(error.localizedDescription)") }
        }
        if !failures.isEmpty { throw CitrusError.partial(outputs,failures) }
        return outputs
    }
    static func textPages(_ text: String) throws -> [CGImage] {
        let attributed = NSAttributedString(string:text.isEmpty ? " " : text,attributes:[.font:NSFont.systemFont(ofSize:23),.foregroundColor:NSColor.black])
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        var pages: [CGImage] = []
        var offset = 0
        while offset < attributed.length {
            let c = try context(width: 1240, height: 1754)
            c.setFillColor(NSColor.white.cgColor); c.fill(CGRect(x: 0, y: 0, width: 1240, height: 1754))
            let path = CGPath(rect:CGRect(x:80,y:80,width:1080,height:1594),transform:nil)
            let frame = CTFramesetterCreateFrame(framesetter,CFRange(location:offset,length:0),path,nil)
            let visible = CTFrameGetVisibleStringRange(frame)
            guard visible.length > 0 else { throw CitrusError.failed("文字排版失败。") }
            CTFrameDraw(frame,c); offset += visible.length
            pages.append(c.makeImage()!)
        }
        return pages
    }
    private static func xml(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
    static func makeDOCX(destination: URL, pages: [CGImage], text: String?) throws {
        let fm = FileManager.default, temp = fm.temporaryDirectory.appendingPathComponent("citrus-docx-\(UUID())")
        try fm.createDirectory(at: temp.appendingPathComponent("word/media"), withIntermediateDirectories: true)
        try fm.createDirectory(at: temp.appendingPathComponent("word/_rels"), withIntermediateDirectories: true)
        try fm.createDirectory(at: temp.appendingPathComponent("_rels"), withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: temp) }
        func write(_ value: String, _ name: String) throws { try Data(value.utf8).write(to: temp.appendingPathComponent(name)) }
        try write("<?xml version=\"1.0\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Default Extension=\"png\" ContentType=\"image/png\"/><Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/></Types>", "[Content_Types].xml")
        try write("<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/></Relationships>", "_rels/.rels")
        var body = "", rels = ""
        if let text {
            body = text.components(separatedBy: .newlines).map { "<w:p><w:r><w:t xml:space=\"preserve\">\(xml($0))</w:t></w:r></w:p>" }.joined()
        }
        for (n, image) in pages.enumerated() {
            let width = 5_486_400, height = Int(Double(width) * Double(image.height) / Double(image.width))
            try imageData(image, format: "png").write(to: temp.appendingPathComponent("word/media/image\(n).png"))
            rels += "<Relationship Id=\"img\(n)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/image\(n).png\"/>"
            body += """
            <w:p><w:r><w:drawing><wp:inline><wp:extent cx="\(width)" cy="\(height)"/><wp:docPr id="\(n+1)" name="Image \(n+1)"/><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic><pic:nvPicPr><pic:cNvPr id="\(n+1)" name="Image"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="img\(n)"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="\(width)" cy="\(height)"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>
            """
            if n < pages.count - 1 { body += "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>" }
        }
        try write("<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\(rels)</Relationships>", "word/_rels/document.xml.rels")
        try write("<?xml version=\"1.0\" encoding=\"UTF-8\"?><w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" xmlns:wp=\"http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing\" xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:pic=\"http://schemas.openxmlformats.org/drawingml/2006/picture\"><w:body>\(body)<w:sectPr><w:pgSz w:w=\"12240\" w:h=\"15840\"/><w:pgMar w:top=\"720\" w:right=\"720\" w:bottom=\"720\" w:left=\"720\"/></w:sectPr></w:body></w:document>", "word/document.xml")
        let archive = fm.temporaryDirectory.appendingPathComponent("citrus-docx-\(UUID()).zip")
        defer { try? fm.removeItem(at:archive) }
        try ProcessRunner.run("/usr/bin/zip", ["-q", "-r", archive.path, "."], directory: temp)
        try Data(contentsOf:archive).write(to:destination,options:.withoutOverwriting)
    }
    static func metadata(_ source: URL) -> [CFString: Any] {
        guard let s = CGImageSourceCreateWithURL(source as CFURL, nil) else { return [:] }
        return CGImageSourceCopyPropertiesAtIndex(s, 0, nil) as? [CFString: Any] ?? [:]
    }
    static func editedMetadata(_ properties:[CFString:Any],clear:Bool,removeLocation:Bool,author:String,caption:String) -> [CFString:Any] {
        var metadata:[CFString:Any] = clear ? [:] : properties
        if removeLocation { metadata.removeValue(forKey:kCGImagePropertyGPSDictionary) }
        metadata.removeValue(forKey:kCGImagePropertyOrientation)
        var tiff = metadata[kCGImagePropertyTIFFDictionary] as? [CFString:Any] ?? [:]
        tiff.removeValue(forKey:kCGImagePropertyTIFFOrientation)
        if !author.isEmpty { tiff[kCGImagePropertyTIFFArtist] = author }
        if !caption.isEmpty { tiff[kCGImagePropertyTIFFImageDescription] = caption }
        if !tiff.isEmpty { metadata[kCGImagePropertyTIFFDictionary] = tiff }
        var png = metadata[kCGImagePropertyPNGDictionary] as? [CFString:Any] ?? [:]
        if !author.isEmpty { png[kCGImagePropertyPNGAuthor] = author }
        if !caption.isEmpty { png[kCGImagePropertyPNGDescription] = caption }
        if !png.isEmpty { metadata[kCGImagePropertyPNGDictionary] = png }
        var iptc = metadata[kCGImagePropertyIPTCDictionary] as? [CFString:Any] ?? [:]
        if !author.isEmpty { iptc[kCGImagePropertyIPTCByline] = [author] }
        if !caption.isEmpty { iptc[kCGImagePropertyIPTCCaptionAbstract] = caption }
        if !iptc.isEmpty { metadata[kCGImagePropertyIPTCDictionary] = iptc }
        return metadata
    }
    static func compress(_ sources: [URL], strong: Bool, maxSide: Int) throws -> [URL] {
        try sources.map { source in
            if FileCatalog.kind(source) == .image {
                let original = try loadImage(source)
                let image = maxSide > 0 ? try resized(original, maxSide: maxSide) : original
                let ext = source.pathExtension.lowercased()
                let originalData = try Data(contentsOf: source)
                let outputFormat = ["jpg", "jpeg", "webp", "heic", "avif"].contains(ext) ? ext : "png"
                var encoded = image
                if outputFormat == "png" {
                    let input = CIImage(cgImage:image).applyingFilter("CIColorPosterize",parameters:["inputLevels":strong ? 16 : 64])
                    encoded = CIContext().createCGImage(input,from:input.extent) ?? image
                }
                let candidate = try imageData(encoded, format:outputFormat, quality: strong ? 0.48 : 0.74)
                guard candidate.count < originalData.count else { throw CitrusError.failed("\(source.lastPathComponent) 已很小；重新压缩无法减小体积。可在设置中开启缩小尺寸。") }
                let out = OutputFiles.available(source: source, suffix: " Compressed", ext:outputFormat)
                try candidate.write(to: out, options: .withoutOverwriting); return out
            }
            let kind = FileCatalog.kind(source)
            let out = OutputFiles.available(source: source, suffix: " Compressed", ext:kind == .audio ? "m4a" : (kind == .video ? "mp4" : source.pathExtension))
            if FileCatalog.kind(source) == .pdf {
                let dpi = strong ? 110.0 : 160.0
                let images = try pdfImages(source,dpi:dpi).map { image -> CGImage in
                    let data = try imageData(image,format:"jpg",quality:strong ? 0.55 : 0.75)
                    return CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithData(data as CFData,nil)!,0,nil)!
                }
                let data = try pdfData(images,dpi:dpi)
                guard data.count < (try Data(contentsOf:source)).count else { throw CitrusError.failed("\(source.lastPathComponent) 已很小，无法进一步减小体积。") }
                try data.write(to: out, options: .withoutOverwriting)
            } else { try MediaEngine.tool(.compress, source: source, destination: out, value: strong ? 30 : 24) }
            return out
        }
    }
    static func splitPDF(_ source: URL) throws -> [URL] {
        guard let doc = PDFDocument(url: source), !doc.isLocked else { throw CitrusError.failed("PDF 无法打开。") }
        return try (0..<doc.pageCount).map { n in
            let result = PDFDocument(); result.insert(doc.page(at: n)!.copy() as! PDFPage, at: 0)
            let out = OutputFiles.available(source: source, suffix: " Page \(String(format: "%03d",n+1))", ext: "pdf")
            guard let data = result.dataRepresentation() else { throw CitrusError.failed("PDF 保存失败。") }
            try data.write(to: out, options: .withoutOverwriting); return out
        }
    }
    static func mergePDF(_ sources: [URL]) throws -> [URL] {
        let doc = PDFDocument()
        for source in sources {
            guard let input = PDFDocument(url: source), !input.isLocked else { throw CitrusError.failed("\(source.lastPathComponent) 无法打开。") }
            for n in 0..<input.pageCount { doc.insert(input.page(at: n)!.copy() as! PDFPage, at: doc.pageCount) }
        }
        guard let first = sources.first, let data = doc.dataRepresentation() else { throw CitrusError.failed("没有可合并的 PDF。") }
        let out = OutputFiles.available(source: first, suffix: " Merged", ext: "pdf"); try data.write(to: out, options: .withoutOverwriting); return [out]
    }
}

enum ProcessRunner {
    @discardableResult static func run(_ executable: String, _ arguments: [String], directory: URL? = nil) throws -> String {
        String(decoding:try runBinary(executable,arguments,directory:directory),as:UTF8.self)
    }
    static func runBinary(_ executable: String, _ arguments: [String], directory: URL? = nil) throws -> Data {
        let process = Process(), pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments; process.currentDirectoryURL = directory?.absoluteURL.standardizedFileURL
        process.standardOutput = pipe; process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
        let output = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else { throw CitrusError.failed(String(output.suffix(1500))) }
        return data
    }
}

enum SubtitleText {
    static func plain(_ text: String) -> String {
        text.components(separatedBy: .newlines).filter { !$0.contains("-->") && Int($0.trimmingCharacters(in: .whitespaces)) == nil && !$0.hasPrefix("WEBVTT") }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func convert(_ text: String, target: String) -> String {
        if !text.contains("-->") {
            let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
            func time(_ seconds: Int) -> String { String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60) + (target == "vtt" ? ".000" : ",000") }
            return (target == "vtt" ? "WEBVTT\n\n" : "") + lines.enumerated().map { "\($0.offset+1)\n\(time($0.offset*3)) --> \(time(($0.offset+1)*3))\n\($0.element)\n" }.joined(separator: "\n")
        }
        let body = text.replacingOccurrences(of: "WEBVTT", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let blocks = body.components(separatedBy: "\n\n").filter { !$0.isEmpty }
        return (target == "vtt" ? "WEBVTT\n\n" : "") + blocks.enumerated().map { n, block in
            let lines = block.components(separatedBy: .newlines).filter { Int($0) == nil }
            return "\(n+1)\n" + lines.map { $0.contains("-->") ? (target == "vtt" ? $0.replacingOccurrences(of: ",", with: ".") : $0.replacingOccurrences(of: ".", with: ",")) : $0 }.joined(separator: "\n")
        }.joined(separator: "\n\n")
    }
}
