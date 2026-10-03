import AppKit
import Observation

enum FileKind: String, Sendable { case image, pdf, audio, video, text, subtitle, archive, unsupported }

enum FileCatalog {
    static let images = ["jpg", "jpeg", "png", "webp", "heic", "heif", "tif", "tiff", "svg", "avif", "bmp", "gif"]
    static let audio = ["mp3", "m4a", "wav", "flac", "ogg", "opus", "aiff", "aif", "wma"]
    static let video = ["mp4", "mov", "mkv", "webm", "avi", "wmv"]
    static func kind(_ url: URL) -> FileKind {
        let ext = url.pathExtension.lowercased()
        if images.contains(ext) { return .image }
        if ext == "pdf" { return .pdf }
        if audio.contains(ext) { return .audio }
        if video.contains(ext) { return .video }
        if ext == "txt" { return .text }
        if ["srt", "vtt"].contains(ext) { return .subtitle }
        if ["zip", "tar", "gz", "tgz", "rar"].contains(ext) { return .archive }
        return .unsupported
    }
    static func formats(_ url: URL) -> [String] {
        let targets: [String]
        switch kind(url) {
        case .image: targets = ["png", "webp", "heic", "tiff", "avif", "bmp", "pdf", "docx", "jpg"]
        case .pdf: targets = ["jpg", "png", "docx", "txt"]
        case .audio: targets = ["mp3", "m4a", "wav", "flac", "ogg", "opus", "aiff", "wma"]
        case .video: targets = ["mp4", "mov", "mkv", "webm", "avi", "wmv", "gif", "mp3"]
        case .text: targets = ["pdf", "jpg", "png", "srt", "vtt"]
        case .subtitle: targets = ["srt", "vtt", "txt"]
        case .archive: targets = ["zip", "tar", "gz"]
        case .unsupported: targets = []
        }
        let raw = url.pathExtension.lowercased()
        let ext = raw == "jpeg" ? "jpg" : (raw == "tif" ? "tiff" : (raw == "heif" ? "heic" : raw))
        return targets.filter { $0 != ext }
    }
    static func tools(_ urls: [URL]) -> [Tool] {
        guard let first = urls.first else { return [] }
        func single(_ url:URL) -> [Tool] {
        switch kind(url) {
        case .image: return [.compress, .metadata, .edit, .annotate, .background, .crop, .redact]
        case .pdf: return [.compress, .metadata, .splitPDF, .mergePDF, .extractText]
        case .video: return [.compress, .metadata, .trim, .mute, .speed, .snapshot]
        case .audio: return [.compress, .metadata, .trim, .normalize, .channels]
        case .archive: return [.extractArchive]
        default: return []
        }
        }
        let common = urls.dropFirst().reduce(Set(single(first))) { $0.intersection(single($1)) }
        var tools = single(first).filter { common.contains($0) }
        if urls.count > 1 {
            tools.removeAll { [.edit,.annotate,.background,.crop,.redact,.trim,.speed,.snapshot,.channels].contains($0) }
            if urls.allSatisfy({ kind($0) == .image }) { tools.append(.createPDF) }
        } else { tools.removeAll { $0 == .mergePDF } }
        return tools
    }
}

enum Tool: String, CaseIterable, Sendable, Identifiable {
    case compress, metadata, edit, annotate, background, crop, redact, createPDF
    case splitPDF, mergePDF, extractText, trim, mute, speed, snapshot, normalize, channels, extractArchive
    var id: String { rawValue }
    var title: String {
        switch self {
        case .compress: return "COMPRESS"
        case .metadata: return "METADATA"
        case .edit: return "EDIT"
        case .annotate: return "ANNOTATE"
        case .background: return "ADD BG"
        case .crop: return "CROP"
        case .redact: return "REDACT"
        case .createPDF: return "CREATE PDF"
        case .splitPDF: return "SPLIT"
        case .mergePDF: return "MERGE PDF"
        case .extractText: return "TEXT"
        case .trim: return "TRIM"
        case .mute: return "MUTE"
        case .speed: return "SPEED"
        case .snapshot: return "SNAPSHOT"
        case .normalize: return "NORMALIZE"
        case .channels: return "CHANNELS"
        case .extractArchive: return "EXTRACT"
        }
    }
    var name: String {
        switch self {
        case .crop: return "Crop Image"
        case .background: return "Add BG"
        case .edit: return "Edit Photo"
        case .annotate: return "Annotate"
        case .redact: return "Redact Photo"
        case .metadata: return "Metadata"
        default: return title.capitalized
        }
    }
    var symbol: String {
        switch self {
        case .compress: return "arrow.down.right.and.arrow.up.left"
        case .metadata: return "tag"
        case .edit: return "slider.horizontal.3"
        case .annotate: return "pencil.tip.crop.circle"
        case .background: return "photo.artframe"
        case .crop: return "crop"
        case .redact: return "eye.slash"
        case .createPDF: return "doc.badge.plus"
        case .splitPDF: return "rectangle.split.2x1"
        case .mergePDF: return "doc.on.doc"
        case .extractText: return "text.alignleft"
        case .trim: return "scissors"
        case .mute: return "speaker.slash"
        case .speed: return "speedometer"
        case .snapshot: return "camera"
        case .normalize: return "waveform"
        case .channels: return "hifispeaker.2"
        case .extractArchive: return "archivebox"
        }
    }
}

enum RadialAction: Equatable, Sendable {
    case convert(String), tool(Tool)
    var title: String { switch self { case .convert(let ext): return ext.uppercased(); case .tool(let tool): return tool.title } }
    var symbol: String? { if case .tool(let tool) = self { return tool.symbol }; return nil }
}

struct RadialGeometry {
    static let diameter: CGFloat = 340
    static let innerRadius: CGFloat = 58
    static let outerRadius: CGFloat = 160
    static func selection(point: CGPoint, count: Int) -> Int? {
        guard count > 0 else { return nil }
        let x = point.x - diameter / 2, y = point.y - diameter / 2
        let distance = hypot(x, y)
        guard distance >= innerRadius + 2, distance <= outerRadius else { return nil }
        var angle = atan2(x, -y)
        if angle < 0 { angle += .pi * 2 }
        return Int(floor((angle + .pi / CGFloat(count)) / (2 * .pi / CGFloat(count)))) % count
    }
    static func frame(center: CGPoint, screen: CGRect) -> CGRect {
        let half = diameter / 2
        return CGRect(x: min(max(center.x - half, screen.minX + 8), screen.maxX - diameter - 8),
                      y: min(max(center.y - half, screen.minY + 8), screen.maxY - diameter - 8),
                      width: diameter, height: diameter)
    }
}

@MainActor @Observable
final class RadialState {
    enum Entry: String { case systemDrag = "system_drag", filePicker = "file_picker", desktopButton = "desktop_button", practice }
    var urls: [URL] = []
    var tools = false
    var selected: Int?
    var pinned = false
    var latchedTools = false
    var appeared = false
    var entry: Entry = .systemDrag
    var dragHover = false
    var allowsStaging: Bool { entry == .desktopButton }
    var actions: [RadialAction] {
        guard let url = urls.first else { return [] }
        if tools { return FileCatalog.tools(urls).map(RadialAction.tool) }
        let common = urls.dropFirst().reduce(Set(FileCatalog.formats(url))) { $0.intersection(FileCatalog.formats($1)) }
        return FileCatalog.formats(url).filter { common.contains($0) }.map(RadialAction.convert)
    }
    var action: RadialAction? { guard let selected, actions.indices.contains(selected) else { return nil }; return actions[selected] }
    func update(point: CGPoint, option: Bool) {
        if entry == .systemDrag { tools = pinned ? (latchedTools || option) : option }
        selected = RadialGeometry.selection(point: point, count: actions.count)
    }
    func setMode(tools: Bool) { self.tools = tools; latchedTools = tools; selected = nil }
}

enum CitrusError: LocalizedError {
    case failed(String)
    case partial([URL],[String])
    var errorDescription: String? {
        switch self { case .failed(let text): return text
        case .partial(let outputs,let errors): return "已生成 \(outputs.count) 个文件，\(errors.count) 个未完成。\n" + errors.joined(separator:"\n") }
    }
}

enum OutputFiles {
    static func available(source: URL, suffix: String = "", ext: String) -> URL {
        let folder = source.deletingLastPathComponent()
        let stem = source.deletingPathExtension().lastPathComponent + suffix
        var candidate = folder.appendingPathComponent(stem).appendingPathExtension(ext)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(stem) (\(n))").appendingPathExtension(ext); n += 1
        }
        return candidate
    }
}
