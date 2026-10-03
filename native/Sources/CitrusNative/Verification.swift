import AppKit
import ImageIO
import PDFKit

@MainActor enum Verification {
    static func fixture(width:Int = 240,height:Int = 320) throws -> CGImage {
        let c = try FileEngine.context(width:width,height:height)
        c.setFillColor(NSColor.white.cgColor); c.fill(CGRect(x:0,y:0,width:width,height:height))
        c.setFillColor(NSColor.systemBlue.cgColor); c.fill(CGRect(x:0,y:CGFloat(height)/2,width:CGFloat(width)/2,height:CGFloat(height)/2))
        c.setFillColor(NSColor.systemRed.cgColor); c.fill(CGRect(x:CGFloat(width)/2,y:0,width:CGFloat(width)/2,height:CGFloat(height)/2))
        return c.makeImage()!
    }
    static func run(directory:URL,failureProbe:Bool=false) throws {
        let root = directory.absoluteURL.standardizedFileURL
        let folder = root.appendingPathComponent("run-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        var checks:[[String:Any]] = []
        var phase = "RUNNING", runnerError = ""
        var outputs:[String] = []
        let started = ISO8601DateFormatter().string(from:Date())
        func persist() throws {
            let passed = checks.filter { $0["status"] as? String == "PASS" }.count
            let failed = checks.filter { $0["status"] as? String == "FAIL" }.count
            let skipped = checks.filter { $0["status"] as? String == "SKIP" }.count
            let result:[String:Any] = ["schema_version":2,"started_at":started,"created_at":ISO8601DateFormatter().string(from:Date()),
                "status":phase,"passed":passed,"failed":failed,"skipped":skipped,"checks":checks,"runner_error":runnerError,
                "fixtures":folder.path,"video_flow_outputs":outputs,"physical_finder_shift_drag":"legacy compatibility requires real UI observation","physical_desktop_button_drag":"requires real Finder observation; automated checks are not product acceptance"]
            let data = try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys])
            try data.write(to:folder.appendingPathComponent("verification.json"),options:.atomic)
            try data.write(to:root.appendingPathComponent("latest.json"),options:.atomic)
        }
        func check(_ name:String,_ pass:Bool,_ detail:String = "") throws {
            checks.append(["name":name,"passed":pass,"status":pass ? "PASS" : "FAIL","detail":detail])
            try persist()
            guard pass else { throw CitrusError.failed("验证失败：\(name) \(detail)") }
        }
        try persist()
        do {
        if failureProbe { try check("forced_failure_probe",false,"Intentional failure to verify receipt persistence and nonzero exit.") }
        let image = try fixture(), source = folder.appendingPathComponent("Sample.png")
        try FileEngine.imageData(image,format:"png").write(to:source)
        let sourceBytes = try Data(contentsOf:source)
        for format in ["jpg","png","webp","heic","tiff","avif","bmp","pdf","docx"] {
            let outputs = try FileEngine.convert([source],format:format)
            let output = outputs[0], bytes = try Data(contentsOf:output)
            if format == "pdf" {
                try check("convert_\(format)",PDFDocument(url:output)?.pageCount == 1 && bytes.starts(with:Data("%PDF".utf8)))
            } else if format == "docx" {
                let list = try ProcessRunner.run("/usr/bin/unzip",["-l",output.path])
                try check("convert_\(format)",list.contains("word/document.xml") && list.contains("word/media/image0.png"))
            } else {
                let decoded = try FileEngine.loadImage(output)
                let type = CGImageSourceCreateWithURL(output as CFURL,nil).flatMap { CGImageSourceGetType($0) as String? } ?? ""
                let expected = ["jpg":"public.jpeg","png":"public.png","webp":"org.webmproject.webp","heic":"public.heic","tiff":"public.tiff","avif":"public.avif","bmp":"com.microsoft.bmp"]
                try check("convert_\(format)",type == expected[format] && decoded.width == 240 && decoded.height == 320 && bytes.count > 0,"\(type), \(decoded.width)×\(decoded.height), \(bytes.count) bytes")
            }
        }
        try check("source_unchanged",try Data(contentsOf:source) == sourceBytes)
        let out1 = try FileEngine.convert([source],format:"jpg")[0]
        let out2 = try FileEngine.convert([source],format:"jpg")[0]
        try check("collision_avoids_overwrite",out1 != out2)
        let crop = try ImageRendering.crop(image,normalized:CGRect(x:0.1,y:0.2,width:0.6,height:0.5))
        let cropOut = try FileEngine.saveImage(crop,source:source,suffix:" Cropped")
        let decodedCrop = try FileEngine.loadImage(cropOut)
        try check("crop_full_resolution",decodedCrop.width == 144 && decodedCrop.height == 160)
        var style = BackgroundStyle(); style.padding = 40; style.corners = 24; style.shadow = 12
        let bg = try ImageRendering.background(crop,style:style)
        let bgOut = try FileEngine.saveImage(bg,source:cropOut,suffix:" BG")
        try check("background_padding",bg.width == 224 && bg.height == 240)
        style.ratio = 16.0/9
        let wide = try ImageRendering.background(crop,style:style)
        try check("background_aspect_ratio",abs(Double(wide.width)/Double(wide.height)-16.0/9) < 0.01)
        let preview = try ImageRendering.background(crop,style:style,previewMax:200)
        try check("preview_matches_export_ratio",abs(Double(preview.width)/Double(preview.height)-Double(wide.width)/Double(wide.height)) < 0.02)
        let pen = PaintMark(kind:.redact,points:[CGPoint(x:0.1,y:0.1),CGPoint(x:0.4,y:0.4)],color:.black,width:12)
        let redacted = try ImageRendering.painted(image,marks:[pen])
        let redactOut = try FileEngine.saveImage(redacted,source:source,suffix:" Redacted")
        let pixel = sample(redacted,x:48,y:64)
        try check("redaction_is_baked_into_pixels",pixel.prefix(3).allSatisfy { $0 < 5 },"\(pixel)")
        var edit = EditSettings(); edit.rotation = 1
        let rotated = try ImageRendering.edited(image,settings:edit)
        try check("rotate_dimensions",rotated.width == 320 && rotated.height == 240)
        edit = EditSettings(); edit.saturation = 0
        let gray = try ImageRendering.edited(image,settings:edit)
        let p = sample(gray,x:48,y:64)
        try check("edit_saturation",abs(Int(p[0])-Int(p[1])) < 3 && abs(Int(p[1])-Int(p[2])) < 3)
        let pdfSource = folder.appendingPathComponent("Two Pages.pdf")
        let small = try fixture(width:72,height:96)
        try FileEngine.pdfData([small,small]).write(to:pdfSource)
        let pages = try FileEngine.convert([pdfSource],format:"jpg")
        try check("pdf_all_pages",pages.count == 2)
        let page = try FileEngine.loadImage(pages[0])
        try check("pdf_300dpi",page.width == 300 && page.height == 400)
        let split = try FileEngine.splitPDF(pdfSource)
        let merged = try FileEngine.mergePDF(split)
        try check("pdf_split_merge",split.count == 2 && PDFDocument(url:merged[0])?.pageCount == 2)
        for n in 0..<8 {
            let theta = CGFloat(n)*CGFloat.pi/4
            let point = CGPoint(x:170+110*sin(theta),y:170-110*cos(theta))
            try check("radial_sector_\(n)",RadialGeometry.selection(point:point,count:8) == n)
        }
        try check("radial_center_cancels",RadialGeometry.selection(point:CGPoint(x:170,y:170),count:8) == nil)
        try check("radial_outside_cancels",RadialGeometry.selection(point:CGPoint(x:500,y:170),count:8) == nil)
        let frame = RadialGeometry.frame(center:CGPoint(x:10,y:10),screen:CGRect(x:0,y:0,width:1440,height:900))
        try check("radial_screen_edge_clamp",frame.minX >= 0 && frame.minY >= 0 && frame.maxX <= 1440 && frame.maxY <= 900)
        try check("current_format_excluded",!FileCatalog.formats(source).contains("png"))
        try check("image_tool_catalog",FileCatalog.tools([source]).count == 7)
        let srt = "1\n00:00:01,500 --> 00:00:03,000\nHello\n\n2\n00:00:04,000 --> 00:00:05,000\n你好"
        let vtt = SubtitleText.convert(srt,target:"vtt")
        try check("subtitle_conversion",vtt.hasPrefix("WEBVTT") && vtt.contains("00:00:01.500") && SubtitleText.plain(vtt).contains("你好"))
        let tagged = folder.appendingPathComponent("Tagged.jpg")
        let tags:[CFString:Any] = [kCGImagePropertyIPTCDictionary:[kCGImagePropertyIPTCByline:["Original Camera"]],kCGImagePropertyGPSDictionary:[kCGImagePropertyGPSLatitude:1.0,kCGImagePropertyGPSLatitudeRef:"N",kCGImagePropertyGPSLongitude:1.0,kCGImagePropertyGPSLongitudeRef:"E"]]
        try FileEngine.imageData(image,format:"jpg",properties:tags).write(to:tagged)
        let taggedData = try Data(contentsOf:tagged)
        let cleaned = FileEngine.editedMetadata(FileEngine.metadata(tagged),clear:true,removeLocation:true,author:"Kris",caption:"Local test")
        let cleanedOut = try FileEngine.saveImage(FileEngine.loadImage(tagged),source:tagged,suffix:" Metadata",properties:cleaned)
        let readback = FileEngine.metadata(cleanedOut)
        try check("metadata_location_removed",readback[kCGImagePropertyGPSDictionary] == nil)
        let iptc = readback[kCGImagePropertyIPTCDictionary] as? [CFString:Any]
        try check("metadata_author_saved",(iptc?[kCGImagePropertyIPTCByline] as? [String])?.first == "Kris")
        try check("metadata_caption_saved",iptc?[kCGImagePropertyIPTCCaptionAbstract] as? String == "Local test")
        try check("metadata_original_preserved",try Data(contentsOf:tagged) == taggedData)
        let compressed = try FileEngine.compress([tagged],strong:true,maxSide:128)[0]
        try check("compression_smaller",(try Data(contentsOf:compressed)).count < taggedData.count)
        let compressedImage = try FileEngine.loadImage(compressed)
        try check("compression_resize",max(compressedImage.width,compressedImage.height) == 128)
        let missing = folder.appendingPathComponent("missing.jpg")
        do { _ = try FileEngine.convert([source,missing],format:"webp"); try check("partial_batch",false) }
        catch CitrusError.partial(let successes,let errors) {
            try check("partial_batch_keeps_successes",successes.count == 1 && errors.count == 1 && FileManager.default.fileExists(atPath:successes[0].path))
        }
        let longText = String(repeating:"这个文本必须完整分页，不能因为换行数量少就截断。 ",count:800)
        try check("text_pagination",try FileEngine.textPages(longText).count > 1)
        let archiveFolder = folder.appendingPathComponent("Archive source")
        try FileManager.default.createDirectory(at:archiveFolder,withIntermediateDirectories:true)
        try Data("Local archive fixture".utf8).write(to:archiveFolder.appendingPathComponent("note.txt"))
        let archive = folder.appendingPathComponent("Archive.zip")
        try ProcessRunner.run("/usr/bin/zip",["-q","-r",archive.path,"."],directory:archiveFolder)
        let extracted = try ArchiveEngine.extract(archive)
        try check("archive_extract",try String(contentsOf:extracted.appendingPathComponent("note.txt"),encoding:.utf8) == "Local archive fixture")
        let tar = try ArchiveEngine.convert(archive,format:"tar")
        try check("archive_convert",try ProcessRunner.run("/usr/bin/tar",["-tf",tar.path]).contains("note.txt"))
        if let ffmpeg = MediaEngine.ffmpeg {
            let audio = folder.appendingPathComponent("Tone.wav")
            try ProcessRunner.run(ffmpeg,["-hide_banner","-loglevel","error","-f","lavfi","-i","sine=frequency=440:duration=2","-n",audio.path])
            let mp3 = try FileEngine.convert([audio],format:"mp3")[0]
            try check("audio_real_encode",(try Data(contentsOf:mp3)).count > 100)
            let video = folder.appendingPathComponent("Clip.mp4")
            try ProcessRunner.run(ffmpeg,["-hide_banner","-loglevel","error","-f","lavfi","-i","testsrc=size=96x64:rate=12","-f","lavfi","-i","sine=frequency=440","-t","2","-c:v","libx264","-pix_fmt","yuv420p","-c:a","aac","-n",video.path])
            let webm = try FileEngine.convert([video],format:"webm")[0]
            try check("video_real_encode",(try Data(contentsOf:webm)).count > 100)
            let muted = folder.appendingPathComponent("Clip Muted.mp4")
            try MediaEngine.tool(.mute,source:video,destination:muted)
            let ffprobe = URL(fileURLWithPath:ffmpeg).deletingLastPathComponent().appendingPathComponent("ffprobe").path
            let streams = try ProcessRunner.run(ffprobe,["-v","error","-select_streams","a","-show_entries","stream=codec_type","-of","csv=p=0",muted.path])
            try check("video_mute_removes_audio",streams.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
            let trimmed = folder.appendingPathComponent("Clip Trimmed.mp4")
            try MediaEngine.tool(.trim,source:video,destination:trimmed,value:0.5,end:1.5)
            let time = try ProcessRunner.run(ffprobe,["-v","error","-show_entries","format=duration","-of","csv=p=0",trimmed.path])
            try check("media_trim_duration",abs((Double(time.trimmingCharacters(in:.whitespacesAndNewlines)) ?? 0)-1) < 0.1)
        } else {
            for name in ["audio_real_encode","video_real_encode","video_mute_removes_audio","media_trim_duration"] {
                checks.append(["name":name,"passed":false,"status":"SKIP","detail":"FFmpeg is not installed."])
            }
            try persist()
        }
        try ExtendedVerification.run(folder:folder,image:image,source:source,check:check)
        try DesktopVerification.run(image:image,source:source,check:check)
        outputs = [source.path,cropOut.path,bgOut.path,redactOut.path]
        phase = checks.contains { $0["status"] as? String == "SKIP" } ? "PASS_WITH_SKIPS" : "PASS"
        try persist()
        let passCount = checks.filter { $0["status"] as? String == "PASS" }.count
        print("\(passCount) checks passed. \(folder.path)")
        } catch {
            phase = "FAIL"; runnerError = error.localizedDescription
            try persist()
            throw error
        }
    }
    static func sample(_ image:CGImage,x:Int,y:Int) -> [UInt8] {
        var data = [UInt8](repeating:0,count:image.width*image.height*4)
        let c = CGContext(data:&data,width:image.width,height:image.height,bitsPerComponent:8,bytesPerRow:image.width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.draw(image,in:CGRect(x:0,y:0,width:image.width,height:image.height))
        let offset = (y*image.width+x)*4
        return Array(data[offset..<offset+4])
    }
}
