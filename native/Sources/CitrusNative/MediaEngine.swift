import Foundation

enum MediaEngine {
    static var ffmpeg: String? {
        ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"].first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    static func execute(_ args: [String], destination: URL) throws {
        guard let ffmpeg else { throw CitrusError.failed("音视频处理需要本机安装 FFmpeg。") }
        do {
            try ProcessRunner.run(ffmpeg, ["-hide_banner", "-loglevel", "error", "-nostdin", "-n"] + args + [destination.path])
            guard (try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0 > 0 else { throw CitrusError.failed("没有生成输出文件。") }
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }
    static func convert(source: URL, destination: URL, format: String) throws {
        var args = ["-i", source.path, "-map_metadata", "-1"]
        switch format {
        case "mp3": args += ["-vn", "-c:a", "libmp3lame", "-q:a", "2"]
        case "m4a": args += ["-vn", "-c:a", "aac", "-b:a", "192k"]
        case "wav": args += ["-vn", "-c:a", "pcm_s16le"]
        case "flac": args += ["-vn", "-c:a", "flac"]
        case "ogg": args += ["-vn", "-c:a", "libvorbis", "-q:a", "5"]
        case "opus": args += ["-vn", "-c:a", "libopus", "-b:a", "128k"]
        case "aiff": args += ["-vn", "-c:a", "pcm_s16be"]
        case "wma": args += ["-vn", "-c:a", "wmav2", "-b:a", "192k"]
        case "gif": args += ["-vf", "fps=12,scale=720:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse", "-an"]
        case "webm": args += ["-c:v", "libvpx-vp9", "-crf", "30", "-b:v", "0", "-c:a", "libopus"]
        case "wmv": args += ["-c:v", "wmv2", "-c:a", "wmav2"]
        case "avi": args += ["-c:v", "mpeg4", "-q:v", "4", "-c:a", "libmp3lame"]
        default: args += ["-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p", "-c:a", "aac"]
        }
        try execute(args, destination: destination)
    }
    static func tool(_ tool: Tool, source: URL, destination: URL, value: Double = 1, end: Double = 0) throws {
        let audio = FileCatalog.kind(source) == .audio
        var args = ["-i", source.path]
        switch tool {
        case .metadata: args += ["-map_metadata", "-1", "-c", "copy"]
        case .compress:
            if audio { args += ["-c:a", "aac", "-b:a", "96k"] }
            else { args += ["-c:v", "libx264", "-crf", String(value), "-preset", "medium", "-c:a", "aac", "-b:a", "128k"] }
        case .mute: args += ["-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p", "-an"]
        case .trim:
            args = ["-ss", String(value), "-i", source.path, "-t", String(max(0.1, end-value))]
            if !audio { args += ["-c:v", "libx264", "-crf", "20", "-c:a", "aac"] }
        case .normalize: args += ["-af", "loudnorm=I=-16:TP=-1.5:LRA=11"]
        case .channels: args += ["-ac", value < 1.5 ? "1" : "2"]
        case .snapshot: args = ["-ss", String(value), "-i", source.path, "-frames:v", "1"]
        case .speed:
            let speed = min(2, max(0.5, value))
            args += ["-filter:v", "setpts=PTS/\(speed)", "-filter:a", "atempo=\(speed)", "-c:v", "libx264", "-crf", "20", "-c:a", "aac"]
        default: throw CitrusError.failed("不支持该音视频操作。")
        }
        try execute(args, destination: destination)
    }
}

enum ArchiveEngine {
    static func validatedEntries(_ source: URL) throws {
        let listing = try ProcessRunner.run("/usr/bin/tar", ["-tf", source.path])
        for name in listing.components(separatedBy: .newlines).filter({ !$0.isEmpty }) {
            guard !name.hasPrefix("/"), !name.components(separatedBy: "/").contains(".."), !name.contains("\0") else { throw CitrusError.failed("压缩包包含不安全的路径。") }
        }
        let details = try ProcessRunner.run("/usr/bin/tar", ["-tvf", source.path])
        guard !details.components(separatedBy: .newlines).contains(where: { $0.hasPrefix("l") || $0.hasPrefix("h") }) else { throw CitrusError.failed("此压缩包包含链接，无法安全解压。") }
    }
    static func extract(_ source: URL) throws -> URL {
        try validatedEntries(source)
        let folder = OutputFiles.available(source: source, suffix: " Extracted", ext: "")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        do { try ProcessRunner.run("/usr/bin/tar", ["--no-same-owner", "--no-same-permissions", "-xf", source.path, "-C", folder.path]) }
        catch { try? FileManager.default.removeItem(at: folder); throw error }
        return folder
    }
    static func convert(_ source: URL, format: String) throws -> URL {
        try validatedEntries(source)
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("citrus-archive-\(UUID())")
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: temp) }
        try ProcessRunner.run("/usr/bin/tar", ["--no-same-owner", "--no-same-permissions", "-xf", source.path, "-C", temp.path])
        let out = OutputFiles.available(source: source, ext: format == "gz" ? "tar.gz" : format)
        if format == "zip" { try ProcessRunner.run("/usr/bin/zip", ["-q", "-r", out.path, "."], directory: temp) }
        else { try ProcessRunner.run("/usr/bin/tar", [format == "gz" ? "-czf" : "-cf", out.path, "-C", temp.path, "."]) }
        return out
    }
}
