import AppKit
import ImageIO

let output = URL(fileURLWithPath:CommandLine.arguments[1])
let size = 1024
let c = CGContext(data:nil,width:size,height:size,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
let base = CGRect(x:16,y:16,width:992,height:992)
c.addPath(CGPath(roundedRect:base,cornerWidth:210,cornerHeight:210,transform:nil)); c.clip()
let background = CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:[NSColor(calibratedRed:1,green:0.96,blue:0.86,alpha:1).cgColor,NSColor(calibratedRed:1,green:0.83,blue:0.55,alpha:1).cgColor] as CFArray,locations:[0,1])!
c.drawLinearGradient(background,start:CGPoint(x:180,y:940),end:CGPoint(x:850,y:50),options:[])
c.saveGState(); c.setShadow(offset:CGSize(width:0,height:-20),blur:28,color:NSColor.brown.withAlphaComponent(0.25).cgColor)
c.setFillColor(NSColor.systemOrange.cgColor); c.fillEllipse(in:CGRect(x:144,y:116,width:736,height:736)); c.restoreGState()
c.saveGState(); c.addEllipse(in:CGRect(x:144,y:116,width:736,height:736)); c.clip()
let orange = CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:[NSColor(calibratedRed:1,green:0.67,blue:0.1,alpha:1).cgColor,NSColor(calibratedRed:0.98,green:0.22,blue:0.025,alpha:1).cgColor] as CFArray,locations:[0,1])!
c.drawLinearGradient(orange,start:CGPoint(x:250,y:820),end:CGPoint(x:760,y:150),options:[]); c.restoreGState()
let leaf = CGMutablePath(); leaf.move(to:CGPoint(x:514,y:825)); leaf.addCurve(to:CGPoint(x:765,y:946),control1:CGPoint(x:578,y:984),control2:CGPoint(x:690,y:955)); leaf.addCurve(to:CGPoint(x:514,y:825),control1:CGPoint(x:734,y:811),control2:CGPoint(x:626,y:800))
c.setFillColor(NSColor(calibratedRed:0.18,green:0.50,blue:0.19,alpha:1).cgColor); c.addPath(leaf); c.fillPath()
c.setStrokeColor(NSColor.white.cgColor); c.setLineWidth(43); c.setLineCap(.round); c.setLineJoin(.round)
for (start,end) in [(0.25,2.7),(Double.pi+0.25,Double.pi+2.7)] {
    c.addArc(center:CGPoint(x:512,y:480),radius:205,startAngle:start,endAngle:end,clockwise:false); c.strokePath()
    let tip = CGPoint(x:512+205*cos(end),y:480+205*sin(end)), angle = end+Double.pi/2, length = 75.0
    c.move(to:CGPoint(x:tip.x-length*cos(angle-0.6),y:tip.y-length*sin(angle-0.6))); c.addLine(to:tip); c.addLine(to:CGPoint(x:tip.x-length*cos(angle+0.6),y:tip.y-length*sin(angle+0.6))); c.strokePath()
}
let destination = CGImageDestinationCreateWithURL(output as CFURL,"public.png" as CFString,1,nil)!
CGImageDestinationAddImage(destination,c.makeImage()!,nil)
if !CGImageDestinationFinalize(destination) { exit(1) }
