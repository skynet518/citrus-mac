import AppKit
import CoreImage

struct BackgroundStyle: Equatable {
    var preset = 0
    var padding: Double = 160
    var corners: Double = 24
    var shadow: Double = 24
    var ratio: Double = 0
    var customColor = NSColor.systemBlue
    var photo: CGImage?
    static func == (lhs: BackgroundStyle, rhs: BackgroundStyle) -> Bool {
        lhs.preset == rhs.preset && lhs.padding == rhs.padding && lhs.corners == rhs.corners && lhs.shadow == rhs.shadow && lhs.ratio == rhs.ratio && lhs.customColor == rhs.customColor && lhs.photo === rhs.photo
    }
}

struct PaintMark {
    enum Kind: String, CaseIterable { case pen, rectangle, arrow, text, redact, blur, pixelate }
    var kind: Kind
    var points: [CGPoint] // Normalized, top-left coordinates.
    var color: NSColor
    var width: Double
    var text: String = ""
}

struct EditSettings: Equatable {
    var exposure = 0.0
    var brightness = 0.0
    var contrast = 1.0
    var saturation = 1.0
    var warmth = 6500.0
    var sharpness = 0.0
    var rotation = 0
    var flip = false
}

enum ImageRendering {
    static let solidColors: [NSColor] = [.white, .systemYellow, .systemGreen, .systemTeal, .systemCyan, .systemBlue, NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.2, alpha: 1), .systemPurple]
    static let gradients: [[NSColor]] = [
        [NSColor(calibratedRed: 1, green: 0.27, blue: 0.52, alpha: 1), NSColor(calibratedRed: 1, green: 0.82, blue: 0.17, alpha: 1), NSColor(calibratedRed: 0.41, green: 0.25, blue: 0.81, alpha: 1)],
        [.systemBlue, .white], [.systemYellow, .systemGreen, .systemCyan], [.systemPink, .white], [.systemPurple, .systemOrange],
        [.systemTeal, .systemPink, .systemYellow], [.systemBlue, .systemCyan], [.systemTeal, .systemMint], [.systemIndigo, .white]
    ]
    static func canvasSize(image: CGImage, style: BackgroundStyle) -> CGSize {
        var width = Double(image.width) + style.padding * 2, height = Double(image.height) + style.padding * 2
        if style.ratio > 0 {
            if width / height < style.ratio { width = height * style.ratio } else { height = width / style.ratio }
        }
        return CGSize(width: ceil(width), height: ceil(height))
    }
    static func background(_ image: CGImage, style: BackgroundStyle, previewMax: Int? = nil) throws -> CGImage {
        let full = canvasSize(image: image, style: style)
        let scale: CGFloat = previewMax == nil ? 1 : min(1, CGFloat(previewMax!) / max(full.width, full.height))
        let c = try FileEngine.context(width: max(1, Int(full.width * scale)), height: max(1, Int(full.height * scale)))
        c.scaleBy(x: scale, y: scale)
        let bounds = CGRect(origin: .zero, size: full)
        if let photo = style.photo, style.preset == 100 {
            let factor = max(full.width / CGFloat(photo.width), full.height / CGFloat(photo.height))
            let w = CGFloat(photo.width) * factor, h = CGFloat(photo.height) * factor
            c.draw(photo, in: CGRect(x: (full.width-w)/2, y: (full.height-h)/2, width: w, height: h))
        } else if style.preset < gradients.count {
            let colors = gradients[max(0, style.preset)]
            let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors.map(\.cgColor) as CFArray, locations: nil)!
            c.drawLinearGradient(gradient, start: CGPoint(x: 0,y: full.height), end: CGPoint(x: full.width,y: 0), options: [.drawsBeforeStartLocation,.drawsAfterEndLocation])
            if style.preset == 0 {
                let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [NSColor.systemYellow.cgColor, NSColor.systemYellow.withAlphaComponent(0).cgColor] as CFArray, locations: [0,1])!
                c.drawRadialGradient(glow, startCenter: CGPoint(x: full.width*0.9,y: full.height*0.9), startRadius: 0,
                                     endCenter: CGPoint(x: full.width*0.9,y: full.height*0.9), endRadius: full.width*0.72, options: [])
                let purple = NSColor(calibratedRed:0.30,green:0.25,blue:0.81,alpha:0.9)
                let purpleGlow = CGGradient(colorsSpace:CGColorSpace(name:CGColorSpace.sRGB),colors:[purple.cgColor,purple.withAlphaComponent(0).cgColor] as CFArray,locations:[0,1])!
                let center = CGPoint(x:full.width*0.95,y:full.height*0.04)
                c.drawRadialGradient(purpleGlow,startCenter:center,startRadius:0,endCenter:center,endRadius:max(full.height*0.82,full.width*0.48),options:[])
            }
        } else {
            let color = style.preset == 99 ? style.customColor : solidColors[min(solidColors.count-1, max(0, style.preset-20))]
            c.setFillColor(color.cgColor); c.fill(bounds)
        }
        let imageWidth = CGFloat(image.width), imageHeight = CGFloat(image.height)
        let rect = CGRect(x: (full.width-imageWidth)/2, y: (full.height-imageHeight)/2, width: imageWidth, height: imageHeight)
        let path = CGPath(roundedRect: rect, cornerWidth: style.corners, cornerHeight: style.corners, transform: nil)
        c.saveGState()
        c.setShadow(offset: CGSize(width: 0,height: -style.shadow/3), blur: style.shadow, color: NSColor.black.withAlphaComponent(0.3).cgColor)
        c.setFillColor(NSColor.white.cgColor); c.addPath(path); c.fillPath(); c.restoreGState()
        c.saveGState(); c.addPath(path); c.clip(); c.draw(image, in: rect); c.restoreGState()
        return c.makeImage()!
    }
    static func crop(_ image: CGImage, normalized: CGRect) throws -> CGImage {
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let rect = CGRect(x: normalized.minX * bounds.width, y: normalized.minY * bounds.height,
                          width: normalized.width * bounds.width, height: normalized.height * bounds.height).integral.intersection(bounds)
        guard rect.width >= 1, rect.height >= 1, let output = image.cropping(to: rect) else { throw CitrusError.failed("裁剪区域无效。") }
        return output
    }
    static func edited(_ image: CGImage, settings: EditSettings) throws -> CGImage {
        var input = CIImage(cgImage: image)
        input = input.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: settings.exposure])
        input = input.applyingFilter("CIColorControls", parameters: [kCIInputBrightnessKey: settings.brightness, kCIInputContrastKey: settings.contrast, kCIInputSaturationKey: settings.saturation])
        input = input.applyingFilter("CITemperatureAndTint", parameters: ["inputNeutral": CIVector(x: settings.warmth, y: 0), "inputTargetNeutral": CIVector(x: 6500, y: 0)])
        if settings.sharpness > 0 { input = input.applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: settings.sharpness]) }
        if settings.flip { input = input.oriented(.upMirrored) }
        for _ in 0..<settings.rotation { input = input.oriented(.right) }
        guard let result = CIContext().createCGImage(input, from: input.extent) else { throw CitrusError.failed("调色失败。") }
        return result
    }
    static func painted(_ image: CGImage, marks: [PaintMark]) throws -> CGImage {
        let c = try FileEngine.context(width: image.width, height: image.height)
        let size = CGSize(width: image.width, height: image.height)
        c.draw(image, in: CGRect(origin: .zero, size: size))
        func pixel(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x*size.width,y: (1-p.y)*size.height) }
        for mark in marks {
            guard let start = mark.points.first else { continue }
            let a = pixel(start), b = pixel(mark.points.last!)
            c.setStrokeColor(mark.color.cgColor); c.setFillColor(mark.color.cgColor)
            c.setLineWidth(mark.width); c.setLineCap(.round); c.setLineJoin(.round)
            let rect = CGRect(x: min(a.x,b.x), y: min(a.y,b.y), width: max(1,abs(b.x-a.x)), height: max(1,abs(b.y-a.y)))
            switch mark.kind {
            case .pen:
                c.beginPath(); c.move(to: a); for p in mark.points.dropFirst() { c.addLine(to: pixel(p)) }; c.strokePath()
            case .rectangle: c.stroke(rect)
            case .arrow:
                c.beginPath(); c.move(to: a); c.addLine(to: b); c.strokePath()
                let angle = atan2(b.y-a.y,b.x-a.x), length = max(20, mark.width*4)
                c.move(to: CGPoint(x: b.x-length*cos(angle-0.5),y: b.y-length*sin(angle-0.5))); c.addLine(to: b)
                c.addLine(to: CGPoint(x: b.x-length*cos(angle+0.5),y: b.y-length*sin(angle+0.5))); c.strokePath()
            case .text:
                let previous = NSGraphicsContext.current
                NSGraphicsContext.current = NSGraphicsContext(cgContext: c, flipped: false)
                (mark.text as NSString).draw(at: a, withAttributes: [.font: NSFont.systemFont(ofSize: max(16,mark.width*5),weight: .semibold), .foregroundColor: mark.color])
                NSGraphicsContext.current = previous
            case .redact: c.fill(rect)
            case .blur, .pixelate:
                let ci = CIImage(cgImage:c.makeImage() ?? image)
                let effect = mark.kind == .blur ? ci.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: max(10,mark.width*3)]) : ci.applyingFilter("CIPixellate", parameters: [kCIInputScaleKey: max(12,mark.width*4)])
                if let filtered = CIContext().createCGImage(effect, from: CGRect(origin: .zero,size: size)) {
                    c.saveGState(); c.clip(to: rect); c.draw(filtered, in: CGRect(origin: .zero,size: size)); c.restoreGState()
                }
            }
        }
        return c.makeImage()!
    }
}
