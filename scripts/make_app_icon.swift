// Renders the 1024x1024 app icon in the mockups' style: a chunky Spark-yellow
// question mark with an ink outline and solid drop shadow on the accent blue.
//
// Usage: swift scripts/make_app_icon.swift App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import AppKit
import CoreText

let size = 1024
let out = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"

func color(_ hex: UInt32) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

let accent = color(0x3B5BFD)
let spark = color(0xFFC93C)
let ink = color(0x17172B)

guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { fatalError("no context") }

// Background: flat accent with a subtle lighter disc behind the glyph.
ctx.setFillColor(accent)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
ctx.setFillColor(color(0x5873FF))
ctx.fillEllipse(in: CGRect(x: 132, y: 132, width: 760, height: 760))

// Glyph: SF Rounded black "?".
let base = NSFont.systemFont(ofSize: 700, weight: .black)
let font = NSFont(descriptor: base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor, size: 700) ?? base
let line = CTLineCreateWithAttributedString(NSAttributedString(string: "?", attributes: [
    .font: font,
    // Let ctx.setFillColor/setStrokeColor control the glyph instead of black.
    NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true,
]))
let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
let origin = CGPoint(x: (CGFloat(size) - bounds.width) / 2 - bounds.minX,
                     y: (CGFloat(size) - bounds.height) / 2 - bounds.minY + 14)

func drawGlyph(offsetY: CGFloat, mode: CGTextDrawingMode, fill: CGColor, stroke: CGColor, width: CGFloat) {
    ctx.saveGState()
    ctx.setTextDrawingMode(mode)
    ctx.setFillColor(fill)
    ctx.setStrokeColor(stroke)
    ctx.setLineWidth(width)
    ctx.setLineJoin(.round)
    ctx.textPosition = CGPoint(x: origin.x, y: origin.y + offsetY)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

drawGlyph(offsetY: -34, mode: .fillStroke, fill: ink, stroke: ink, width: 36)   // drop shadow
drawGlyph(offsetY: 0, mode: .fillStroke, fill: ink, stroke: ink, width: 36)     // outline
drawGlyph(offsetY: 0, mode: .fill, fill: spark, stroke: spark, width: 0)        // face

guard let image = ctx.makeImage(),
      let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
    fatalError("render failed")
}
try data.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
