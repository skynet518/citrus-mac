import AppKit
import SwiftUI

@MainActor
final class CropCanvas: NSView {
    var image: CGImage?
    var selection = CGRect(x:0,y:0,width:1,height:1)
    var aspectRatio: Double = 0
    var onChange: ((CGRect) -> Void)?
    private var anchor = CGPoint.zero
    private var initial = CGRect.zero
    private var handle = -1
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    var imageRect: CGRect {
        guard let image else { return bounds }
        let factor = min((bounds.width-24)/CGFloat(image.width),(bounds.height-24)/CGFloat(image.height))
        let width = CGFloat(image.width)*factor, height = CGFloat(image.height)*factor
        return CGRect(x:(bounds.width-width)/2,y:(bounds.height-height)/2,width:width,height:height)
    }
    var cropRect: CGRect {
        let r = imageRect
        return CGRect(x:r.minX+selection.minX*r.width,y:r.minY+selection.minY*r.height,width:selection.width*r.width,height:selection.height*r.height)
    }
    var handles: [CGPoint] {
        let r = cropRect
        return [CGPoint(x:r.minX,y:r.minY),CGPoint(x:r.midX,y:r.minY),CGPoint(x:r.maxX,y:r.minY),
                CGPoint(x:r.maxX,y:r.midY),CGPoint(x:r.maxX,y:r.maxY),CGPoint(x:r.midX,y:r.maxY),CGPoint(x:r.minX,y:r.maxY),CGPoint(x:r.minX,y:r.midY)]
    }
    override func draw(_ dirtyRect:NSRect) {
        guard let image else { return }
        NSImage(cgImage:image,size:.zero).draw(in:imageRect,from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:nil)
        let overlay = NSBezierPath(rect:imageRect); overlay.appendRect(cropRect); overlay.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.58).setFill(); overlay.fill()
        NSColor(calibratedRed:0.9,green:0.22,blue:0.05,alpha:1).setStroke()
        let border = NSBezierPath(rect:cropRect); border.lineWidth = 1.7; border.stroke()
        if window?.firstResponder === self {
            NSColor.white.withAlphaComponent(0.32).setStroke()
            let grid = NSBezierPath()
            for n in 1...2 {
                grid.move(to:CGPoint(x:cropRect.minX+cropRect.width*CGFloat(n)/3,y:cropRect.minY)); grid.line(to:CGPoint(x:cropRect.minX+cropRect.width*CGFloat(n)/3,y:cropRect.maxY))
                grid.move(to:CGPoint(x:cropRect.minX,y:cropRect.minY+cropRect.height*CGFloat(n)/3)); grid.line(to:CGPoint(x:cropRect.maxX,y:cropRect.minY+cropRect.height*CGFloat(n)/3))
            }
            grid.lineWidth = 0.5; grid.stroke()
        }
        NSColor(calibratedRed:0.9,green:0.22,blue:0.05,alpha:1).setFill()
        for p in handles { NSBezierPath(roundedRect:CGRect(x:p.x-4,y:p.y-4,width:8,height:8),xRadius:1,yRadius:1).fill() }
    }
    override func mouseDown(with event:NSEvent) {
        let p = convert(event.locationInWindow,from:nil)
        guard imageRect.insetBy(dx:-12,dy:-12).contains(p) else { return }
        window?.makeFirstResponder(self)
        anchor = p; initial = selection
        handle = handles.enumerated().min(by: { hypot($0.element.x-p.x,$0.element.y-p.y) < hypot($1.element.x-p.x,$1.element.y-p.y) }).flatMap { hypot($0.element.x-p.x,$0.element.y-p.y) < 13 ? $0.offset : nil } ?? (cropRect.contains(p) ? 8 : 9)
        if handle == 9 { let r = imageRect; initial = CGRect(x:(p.x-r.minX)/r.width,y:(p.y-r.minY)/r.height,width:0,height:0) }
        needsDisplay = true
    }
    override func mouseDragged(with event:NSEvent) {
        let p = convert(event.locationInWindow,from:nil), r = imageRect
        let dx = (p.x-anchor.x)/r.width, dy = (p.y-anchor.y)/r.height
        var result = initial
        if handle == 8 {
            result.origin.x = min(1-result.width,max(0,initial.minX+dx)); result.origin.y = min(1-result.height,max(0,initial.minY+dy))
        } else if handle == 9 {
            result = CGRect(x:min(initial.minX,initial.minX+dx),y:min(initial.minY,initial.minY+dy),width:abs(dx),height:abs(dy))
        } else {
            var left = initial.minX, right = initial.maxX, top = initial.minY, bottom = initial.maxY
            if [0,6,7].contains(handle) { left = min(right-0.005,max(0,left+dx)) }
            if [2,3,4].contains(handle) { right = max(left+0.005,min(1,right+dx)) }
            if [0,1,2].contains(handle) { top = min(bottom-0.005,max(0,top+dy)) }
            if [4,5,6].contains(handle) { bottom = max(top+0.005,min(1,bottom+dy)) }
            result = CGRect(x:left,y:top,width:right-left,height:bottom-top)
        }
        if aspectRatio > 0, let image, handle != 8 {
            let ratio = aspectRatio*Double(image.height)/Double(image.width)
            var width = result.width, height = width/ratio
            if height > 1 { height = 1; width = height*ratio }
            if width > 1 { width = 1; height = width/ratio }
            let leftAnchored = [2,3,4,9].contains(handle)
            let topAnchored = [4,5,6,9].contains(handle)
            result = CGRect(x:leftAnchored ? initial.minX : initial.maxX-width,y:topAnchored ? initial.minY : initial.maxY-height,width:width,height:height)
            result.origin.x = min(1-width,max(0,result.minX)); result.origin.y = min(1-height,max(0,result.minY))
        }
        result = result.intersection(CGRect(x:0,y:0,width:1,height:1))
        if result.width > 0.003 && result.height > 0.003 { selection = result; onChange?(result); needsDisplay = true }
    }
}

struct CropSurface: NSViewRepresentable {
    let image:CGImage
    @Binding var rect:CGRect
    var ratio:Double
    func makeNSView(context:Context) -> CropCanvas {
        let view = CropCanvas(); view.setAccessibilityElement(true); view.setAccessibilityRole(.image); view.setAccessibilityLabel("拖动裁剪边框和八个手柄，调整裁剪区域")
        return view
    }
    func updateNSView(_ view:CropCanvas,context:Context) {
        view.image = image; view.selection = rect; view.aspectRatio = ratio
        view.onChange = { rect = $0 }; view.needsDisplay = true
    }
}

@MainActor
final class PaintCanvas: NSView {
    var image:CGImage?
    var marks:[PaintMark] = []
    var kind:PaintMark.Kind = .pen
    var color:NSColor = .systemRed
    var lineWidth:Double = 12
    var text = ""
    var onChange:(([PaintMark]) -> Void)?
    private var active:PaintMark?
    private var preview:CGImage?
    private var previewSource:CGImage?
    override var isFlipped:Bool { true }
    var imageRect:CGRect {
        guard let image else { return bounds }
        let factor = min((bounds.width-16)/CGFloat(image.width),(bounds.height-16)/CGFloat(image.height))
        let width = CGFloat(image.width)*factor, height = CGFloat(image.height)*factor
        return CGRect(x:(bounds.width-width)/2,y:(bounds.height-height)/2,width:width,height:height)
    }
    func normalized(_ point:CGPoint) -> CGPoint { let r = imageRect; return CGPoint(x:min(1,max(0,(point.x-r.minX)/r.width)),y:min(1,max(0,(point.y-r.minY)/r.height))) }
    override func draw(_ dirtyRect:NSRect) {
        guard let image else { return }
        if previewSource !== image { previewSource = image; preview = try? FileEngine.resized(image,maxSide:1200) }
        let base = preview ?? image
        let factor = Double(base.width)/Double(image.width)
        let previewMarks = (marks+(active.map { [$0] } ?? [])).map { mark in var m = mark; m.width *= factor; return m }
        let display = (try? ImageRendering.painted(base,marks:previewMarks)) ?? base
        NSImage(cgImage:display,size:.zero).draw(in:imageRect,from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:nil)
    }
    override func mouseDown(with event:NSEvent) {
        let p = convert(event.locationInWindow,from:nil); guard imageRect.contains(p) else { return }
        active = PaintMark(kind:kind,points:[normalized(p)],color:color,width:lineWidth,text:text); needsDisplay = true
    }
    override func mouseDragged(with event:NSEvent) {
        guard var mark = active else { return }
        let p = normalized(convert(event.locationInWindow,from:nil))
        if kind == .pen { mark.points.append(p) } else { mark.points = [mark.points[0],p] }
        active = mark
        needsDisplay = true
    }
    override func mouseUp(with event:NSEvent) {
        if let active { marks.append(active); onChange?(marks) }
        active = nil; needsDisplay = true
    }
}

struct PaintSurface: NSViewRepresentable {
    let image:CGImage
    @Binding var marks:[PaintMark]
    let kind:PaintMark.Kind
    let color:NSColor
    let lineWidth:Double
    let text:String
    func makeNSView(context:Context) -> PaintCanvas {
        let view = PaintCanvas(); view.setAccessibilityElement(true); view.setAccessibilityRole(.image); view.setAccessibilityLabel("在图片上拖动以添加标注或遮挡")
        return view
    }
    func updateNSView(_ view:PaintCanvas,context:Context) {
        view.image = image; view.marks = marks; view.kind = kind; view.color = color; view.lineWidth = lineWidth; view.text = text
        view.onChange = { marks = $0 }; view.needsDisplay = true
    }
}
