import AppKit
import Foundation
import ImageIO
import PDFKit

@MainActor enum ExtendedVerification {
    typealias Check = (String,Bool,String) throws -> Void
    static func run(folder:URL,image:CGImage,source:URL,check:Check) throws {
        func rejected(_ action:() throws -> Void) -> Bool { do { try action(); return false } catch { return true } }
        func save(_ image:CGImage,_ name:String,_ format:String,properties:[CFString:Any]=[:]) throws -> URL {
            let url = folder.appendingPathComponent(name)
            try FileEngine.imageData(image,format:format,properties:properties).write(to:url,options:.withoutOverwriting)
            return url
        }

        // Regression: a fresh Finder pasteboard must work even without a mouse-drag callback.
        var gate = DragSessionGate(baseline:10)
        try check("drag_stale_pasteboard_ignored",!gate.observe(changeCount:10,leftDown:true,ownWindow:false),"Old file drag + held mouse does not activate.")
        try check("drag_fresh_pasteboard_without_event",gate.observe(changeCount:11,leftDown:true,ownWindow:false),"Fresh file drag activates without an NSEvent callback; physical Shift remains a separate manual check.")
        try check("drag_editor_mouse_ignored",!gate.observe(changeCount:11,leftDown:true,ownWindow:true),"Crop, paint and window drags stay outside the desktop entry.")
        gate.consume()
        try check("drag_consumed_session_stays_closed",!gate.observe(changeCount:12,leftDown:true,ownWindow:false),"Esc/drop consumes the session until button release.")
        _ = gate.observe(changeCount:12,leftDown:false,ownWindow:false)
        try check("drag_next_session_rearms",!gate.observe(changeCount:12,leftDown:true,ownWindow:false) && gate.observe(changeCount:13,leftDown:true,ownWindow:false),"Release resets the baseline; a new file drag re-arms.")
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        _ = board.writeObjects([source as NSURL])
        try check("drag_modern_file_url_read",DragFiles.read(board) == [source],"Private pasteboard with public.file-url.")
        board.clearContents()
        board.setPropertyList([source.path,source.path,folder.appendingPathComponent("ignore.xyz").path],forType:NSPasteboard.PasteboardType("NSFilenamesPboardType"))
        try check("drag_legacy_file_paths_read",DragFiles.read(board) == [source],"NSFilenamesPboardType works, duplicates and unsupported extensions are filtered.")

        let alphaContext = try FileEngine.context(width:64,height:64)
        alphaContext.setFillColor(NSColor(calibratedRed:1,green:0,blue:0,alpha:0.5).cgColor)
        alphaContext.fill(CGRect(x:16,y:16,width:32,height:32))
        let transparent = alphaContext.makeImage()!
        for ext in ["png","webp"] {
            let url = try save(transparent,"Transparent.\(ext)",ext)
            let decoded = try FileEngine.loadImage(url), clear = Verification.sample(decoded,x:0,y:0), mid = Verification.sample(decoded,x:32,y:32)
            try check("transparency_\(ext)",clear[3] == 0 && abs(Int(mid[3])-128) <= 3 && abs(Int(mid[0])-Int(mid[3])) <= 4,"Corner \(clear); half-transparent red center \(mid), premultiplied RGBA.")
        }
        let whiteURL = try save(transparent,"Transparent.jpg","jpg")
        let whitePixel = Verification.sample(try FileEngine.loadImage(whiteURL),x:0,y:0)
        try check("jpeg_transparency_white",whitePixel.prefix(3).allSatisfy { $0 > 245 },"Transparent corner becomes white: \(whitePixel).")
        let orientURL = try save(image,"Orientation6.jpg","jpg",properties:[kCGImagePropertyOrientation:6])
        let oriented = try FileEngine.loadImage(orientURL)
        try check("exif_orientation_applied",oriented.width == 320 && oriented.height == 240,"EXIF orientation 6 loads as 320×240.")
        let normalized = try FileEngine.saveImage(oriented,source:orientURL,suffix:" Normalized")
        try check("exif_orientation_not_applied_twice",FileEngine.metadata(normalized)[kCGImagePropertyOrientation] == nil && (try FileEngine.loadImage(normalized)).width == 320,"Export has normalized pixels and no stale orientation tag.")
        let broken = folder.appendingPathComponent("Corrupt.png"); try Data("broken image".utf8).write(to:broken)
        try check("corrupt_image_rejected",rejected { _ = try FileEngine.loadImage(broken) },"Malformed PNG is rejected.")
        try check("oversized_canvas_rejected",rejected { _ = try FileEngine.context(width:24001,height:1) },"Width above 24000 is rejected before allocation.")
        try check("outside_crop_rejected",rejected { _ = try ImageRendering.crop(image,normalized:CGRect(x:2,y:2,width:0.1,height:0.1)) },"Crop completely outside the image is rejected.")

        let tagged = folder.appendingPathComponent("Tagged.jpg")
        let existing = FileEngine.metadata(tagged)
        let gpsOnly = FileEngine.editedMetadata(existing,clear:false,removeLocation:true,author:"",caption:"")
        let gpsOut = try FileEngine.saveImage(FileEngine.loadImage(tagged),source:tagged,suffix:" GPS Only",properties:gpsOnly)
        let gpsRead = FileEngine.metadata(gpsOut), iptc = gpsRead[kCGImagePropertyIPTCDictionary] as? [CFString:Any]
        try check("gps_only_removal_keeps_author",gpsRead[kCGImagePropertyGPSDictionary] == nil && (iptc?[kCGImagePropertyIPTCByline] as? [String])?.first == "Original Camera","Removing only location preserves the existing author.")
        let retained = FileEngine.editedMetadata(existing,clear:false,removeLocation:false,author:"",caption:"")
        let retainedOut = try FileEngine.saveImage(FileEngine.loadImage(tagged),source:tagged,suffix:" GPS Retained",properties:retained)
        let gps = FileEngine.metadata(retainedOut)[kCGImagePropertyGPSDictionary] as? [CFString:Any]
        try check("gps_preserved_when_requested",abs((gps?[kCGImagePropertyGPSLatitude] as? Double ?? 0)-1) < 0.001,"Location remains only when removal is disabled.")
        let chinese = FileEngine.editedMetadata([:],clear:true,removeLocation:true,author:"橘子测试",caption:"中文描述")
        let chineseOut = try save(image,"Chinese Metadata.png","png",properties:chinese)
        let png = FileEngine.metadata(chineseOut)[kCGImagePropertyPNGDictionary] as? [CFString:Any]
        try check("png_unicode_metadata",png?[kCGImagePropertyPNGAuthor] as? String == "橘子测试" && png?[kCGImagePropertyPNGDescription] as? String == "中文描述","PNG author and description survive Unicode round-trip.")

        let noise = try noiseFixture(width:256,height:256)
        let noiseJPG = folder.appendingPathComponent("Noise.jpg")
        try FileEngine.imageData(noise,format:"jpg",quality:1).write(to:noiseJPG)
        let compressed = try FileEngine.compress([noiseJPG],strong:true,maxSide:0)[0]
        let decodedCompressed = try FileEngine.loadImage(compressed)
        try check("jpeg_compression_preserves_dimensions",decodedCompressed.width == 256 && decodedCompressed.height == 256 && (try Data(contentsOf:compressed)).count < (try Data(contentsOf:noiseJPG)).count,"JPEG compression without resizing remains 256×256 and shrinks bytes.")
        let noisePNG = try save(noise,"Noise.png","png")
        let compressedPNG = try FileEngine.compress([noisePNG],strong:true,maxSide:0)[0]
        try check("png_compression_shrinks",(try Data(contentsOf:compressedPNG)).count < (try Data(contentsOf:noisePNG)).count && (try FileEngine.loadImage(compressedPNG)).width == 256,"PNG uses lossy color quantization; size stays 256×256.")
        let noisePDF = folder.appendingPathComponent("Noise.pdf")
        try FileEngine.pdfData([noise],dpi:300).write(to:noisePDF)
        let compressedPDF = try FileEngine.compress([noisePDF],strong:true,maxSide:0)[0]
        let beforePDF = PDFDocument(url:noisePDF)!, afterPDF = PDFDocument(url:compressedPDF)!
        let beforeBox = beforePDF.page(at:0)!.bounds(for:.mediaBox), afterBox = afterPDF.page(at:0)!.bounds(for:.mediaBox)
        try check("pdf_compression_page_geometry",afterPDF.pageCount == 1 && abs(beforeBox.width-afterBox.width) < 1 && abs(beforeBox.height-afterBox.height) < 1 && (try Data(contentsOf:compressedPDF)).count < (try Data(contentsOf:noisePDF)).count,"Raster compression shrinks bytes and preserves page dimensions within 1 pt; searchable text is not retained.")
        let missing = folder.appendingPathComponent("missing.jpg")
        var allFailed = false
        do { _ = try FileEngine.convert([missing,folder.appendingPathComponent("missing2.jpg")],format:"png") }
        catch CitrusError.partial(let outputs,let errors) { allFailed = outputs.isEmpty && errors.count == 2 }
        try check("batch_all_failures_reported",allFailed,"Two missing inputs produce zero successes and two explicit errors.")

        var style = BackgroundStyle(); style.preset = 99; style.customColor = .green; style.padding = 40; style.corners = 30; style.shadow = 0
        let solid = try ImageRendering.background(image,style:style), corner = Verification.sample(solid,x:2,y:2)
        try check("background_custom_color",corner[0] < 10 && corner[1] > 240 && corner[2] < 10,"Custom green background corner: \(corner).")
        let cutCorner = Verification.sample(solid,x:41,y:41)
        try check("background_rounded_corner",cutCorner[0] < 10 && cutCorner[1] > 240 && cutCorner[2] < 10,"Rounded image corner reveals the background: \(cutCorner).")
        let photoContext = try FileEngine.context(width:64,height:64); photoContext.setFillColor(NSColor.green.cgColor); photoContext.fill(CGRect(x:0,y:0,width:64,height:64))
        style.preset = 100; style.photo = photoContext.makeImage()
        let photoPixel = Verification.sample(try ImageRendering.background(image,style:style),x:2,y:2)
        try check("background_photo_rendered",photoPixel[1] > 240 && photoPixel[0] < 10,"Photo background is composited into the exported pixels.")
        let originalPixels = pixels(image)
        for kind in [PaintMark.Kind.pen,.rectangle,.arrow,.text] {
            let mark = PaintMark(kind:kind,points:[CGPoint(x:0.2,y:0.2),CGPoint(x:0.7,y:0.6)],color:.green,width:12,text:"Citrus")
            let painted = try ImageRendering.painted(image,marks:[mark])
            let url = try save(painted,"Annotated \(kind.rawValue).png","png")
            let renderedPixels = pixels(try FileEngine.loadImage(url))
            let changed = zip(originalPixels,renderedPixels).filter { abs(Int($0)-Int($1)) > 20 }.count
            try check("annotation_\(kind.rawValue)_export",changed > 100,"Decoded export has \(changed) changed color bytes, with actual raster annotation.")
        }
        let whiteContext = try FileEngine.context(width:240,height:320); whiteContext.setFillColor(NSColor.white.cgColor); whiteContext.fill(CGRect(x:0,y:0,width:240,height:320))
        let white = whiteContext.makeImage()!
        let block = PaintMark(kind:.redact,points:[CGPoint(x:0.1,y:0.1),CGPoint(x:0.9,y:0.9)],color:.black,width:2)
        for kind in [PaintMark.Kind.blur,.pixelate] {
            let effect = PaintMark(kind:kind,points:[CGPoint(x:0.3,y:0.3),CGPoint(x:0.7,y:0.7)],color:.black,width:2)
            let hidden = try ImageRendering.painted(white,marks:[block,effect])
            let pixel = Verification.sample(hidden,x:120,y:160)
            try check("redaction_then_\(kind.rawValue)_stays_hidden",pixel.prefix(3).allSatisfy { $0 < 5 },"Later \(kind.rawValue) uses the already redacted pixels; center \(pixel).")
        }
        let model = ImageEditorModel(tool:.crop,source:source,image:image)
        model.cropRatio = 1; model.setRatio()
        let square = try ImageRendering.crop(image,normalized:model.cropRect)
        try check("crop_ratio_model",square.width == 240 && square.height == 240,"Selecting 1:1 produces 240×240 from 240×320.")
        model.cropRatio = 0; model.widthText = "120"; model.heightText = "90"; model.applyDimensions()
        let precise = try ImageRendering.crop(image,normalized:model.cropRect)
        try check("crop_pixel_dimensions",precise.width == 120 && precise.height == 90,"Pixel fields drive actual 120×90 output.")
        model.reset()
        try check("editor_reset_restores_original",model.cropRect == CGRect(x:0,y:0,width:1,height:1) && model.widthText == "240" && model.heightText == "320" && model.cropRatio == 0 && model.marks.isEmpty,"Reset restores crop, pixel fields and annotation state.")
        let state = RadialState(); state.urls = [folder.appendingPathComponent("Sample.jpg")]
        state.update(point:CGPoint(x:170,y:60),option:true)
        try check("option_switches_seven_tools",state.tools && state.actions.count == 7 && state.action == .tool(.compress),"Option changes the JPEG menu to seven tools.")
        state.update(point:CGPoint(x:170,y:60),option:false)
        try check("option_release_restores_formats",!state.tools && state.actions.count == 8 && state.action == .convert("png"),"Releasing Option restores eight JPEG format targets.")
        state.urls = [source,folder.appendingPathComponent("Two Pages.pdf")]
        let formats = state.actions
        try check("mixed_batch_common_actions",Set(formats.map(\.title)) == Set(["JPG","DOCX"]) && FileCatalog.tools(state.urls) == [.compress,.metadata],"PNG + PDF exposes only their common conversions and tools; format order follows the first file.")

        let docx = folder.appendingPathComponent("Sample.docx")
        var parsed = true
        for name in ["[Content_Types].xml","_rels/.rels","word/document.xml","word/_rels/document.xml.rels"] {
            // unzip treats square brackets as glob syntax.
            let pattern = name == "[Content_Types].xml" ? "\\[Content_Types\\].xml" : name
            let xml = try ProcessRunner.run("/usr/bin/unzip",["-p",docx.path,pattern])
            parsed = XMLParser(data:Data(xml.utf8)).parse() && parsed
        }
        try check("docx_xml_parts_parse",parsed,"Content types, package relationships, document and image relationships all parse as XML.")
        let embeddedPath = folder.appendingPathComponent("DOCX Embedded.png")
        let embedded = try ProcessRunner.runBinary("/usr/bin/unzip",["-p",docx.path,"word/media/image0.png"])
        try embedded.write(to:embeddedPath)
        let embeddedImage = try FileEngine.loadImage(embeddedPath)
        try check("docx_embedded_image_decodes",embeddedImage.width == 240 && embeddedImage.height == 320,"DOCX contains a real, decodable 240×320 image. Office rendering remains manual.")
        let tailText = String(repeating:"Citrus pagination test. ",count:1500)+"\nFINAL PAGE SENTINEL"
        let textPages = try FileEngine.textPages(tailText)
        let recognized = try FileEngine.recognizeText(textPages.last!).uppercased()
        try check("text_last_page_contains_tail",textPages.count > 1 && recognized.contains("FINAL PAGE SENTINEL"),"OCR of the last rendered page confirms the ending text was not truncated.")

        let unsafeFolder = folder.appendingPathComponent("Unsafe archive source")
        try FileManager.default.createDirectory(at:unsafeFolder,withIntermediateDirectories:true)
        try FileManager.default.createSymbolicLink(at:unsafeFolder.appendingPathComponent("escape"),withDestinationURL:source)
        let unsafeZIP = folder.appendingPathComponent("Unsafe.zip")
        try ProcessRunner.run("/usr/bin/zip",["-q","-y",unsafeZIP.path,"escape"],directory:unsafeFolder)
        try check("archive_symlink_rejected",rejected { _ = try ArchiveEngine.extract(unsafeZIP) },"ZIP containing a symbolic link is rejected before extraction.")
        if let ffmpeg = MediaEngine.ffmpeg {
            let ffprobe = URL(fileURLWithPath:ffmpeg).deletingLastPathComponent().appendingPathComponent("ffprobe").path
            for (name,file,codec) in [("audio_stream_fully_decodes","Tone.mp3","mp3"),("video_stream_fully_decodes","Clip.webm","vp9")] {
                let url = folder.appendingPathComponent(file)
                let stream = try ProcessRunner.run(ffprobe,["-v","error","-select_streams",file.hasSuffix("mp3") ? "a:0" : "v:0","-show_entries","stream=codec_name","-of","csv=p=0",url.path]).trimmingCharacters(in:.whitespacesAndNewlines)
                try ProcessRunner.run(ffmpeg,["-v","error","-xerror","-i",url.path,"-f","null","-"])
                try check(name,stream == codec,"Expected \(codec) codec and complete FFmpeg decode without errors.")
            }
        }
    }
    static func pixels(_ image:CGImage) -> [UInt8] {
        var data = [UInt8](repeating:0,count:image.width*image.height*4)
        let c = CGContext(data:&data,width:image.width,height:image.height,bitsPerComponent:8,bytesPerRow:image.width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.draw(image,in:CGRect(x:0,y:0,width:image.width,height:image.height)); return data
    }
    static func noiseFixture(width:Int,height:Int) throws -> CGImage {
        var state:UInt32 = 12345, bytes = [UInt8](repeating:255,count:width*height*4)
        for i in bytes.indices where i % 4 != 3 { state = 1664525 &* state &+ 1013904223; bytes[i] = UInt8(truncatingIfNeeded:state >> 24) }
        return bytes.withUnsafeMutableBytes { buffer in
            CGContext(data:buffer.baseAddress,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
        }
    }
}
