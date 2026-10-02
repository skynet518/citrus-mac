import AppKit

enum CitrusStatusIcon {
    static func make() -> NSImage {
        let image = NSImage(size:NSSize(width:22,height:22),flipped:false) { _ in
            NSColor.white.setFill()
            let fruit = NSBezierPath(ovalIn:NSRect(x:3,y:1.5,width:16,height:15.5))
            fruit.fill()
            let leaf = NSBezierPath()
            leaf.move(to:NSPoint(x:11.3,y:17))
            leaf.curve(to:NSPoint(x:19.7,y:21),controlPoint1:NSPoint(x:12,y:21.1),controlPoint2:NSPoint(x:16.4,y:21.8))
            leaf.curve(to:NSPoint(x:11.3,y:17),controlPoint1:NSPoint(x:18.9,y:17.2),controlPoint2:NSPoint(x:15.3,y:16.2))
            leaf.fill()
            let stem = NSBezierPath()
            stem.move(to:NSPoint(x:10.7,y:15.5)); stem.line(to:NSPoint(x:10.1,y:19.2))
            stem.lineWidth = 1.8; stem.lineCapStyle = .round
            NSColor.white.setStroke(); stem.stroke()
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = "白色橘子 · 文件转换与编辑"
        return image
    }
}
