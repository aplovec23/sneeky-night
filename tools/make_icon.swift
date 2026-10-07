// Draws the app icon: a moon over a night sky with a golden key.
// Run: swift tools/make_icon.swift
import AppKit

let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let s = CGFloat(size)

NSGradient(starting: NSColor(red: 0.22, green: 0.13, blue: 0.40, alpha: 1),
           ending: NSColor(red: 0.05, green: 0.06, blue: 0.20, alpha: 1))!
    .draw(in: NSRect(x: 0, y: 0, width: s, height: s), angle: 90)

var seed: UInt64 = 11
func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((seed >> 33) % 10000) / 10000 }
NSColor.white.withAlphaComponent(0.85).setFill()
for _ in 0..<45 { let r = 4 + rnd() * 8; NSBezierPath(ovalIn: NSRect(x: rnd() * s, y: rnd() * s, width: r, height: r)).fill() }

// Crescent moon
NSColor(red: 1, green: 0.95, blue: 0.75, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 180, y: 430, width: 480, height: 480)).fill()
NSGradient(starting: NSColor(red: 0.20, green: 0.13, blue: 0.40, alpha: 1),
           ending: NSColor(red: 0.13, green: 0.10, blue: 0.32, alpha: 1))!
    .draw(in: NSBezierPath(ovalIn: NSRect(x: 330, y: 520, width: 440, height: 440)), angle: 90)

// Golden key
let gold = NSColor(red: 1, green: 0.80, blue: 0.25, alpha: 1)
let ctx = NSGraphicsContext.current!.cgContext
ctx.saveGState()
ctx.translateBy(x: 560, y: 330)
ctx.rotate(by: .pi / 5)
gold.setFill()
NSBezierPath(ovalIn: NSRect(x: -150, y: -110, width: 220, height: 220)).fill()
NSBezierPath(roundedRect: NSRect(x: 40, y: -30, width: 340, height: 60), xRadius: 20, yRadius: 20).fill()
NSBezierPath(rect: NSRect(x: 280, y: -110, width: 44, height: 90)).fill()
NSBezierPath(rect: NSRect(x: 340, y: -90, width: 40, height: 70)).fill()
NSColor(red: 0.13, green: 0.10, blue: 0.32, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: -90, y: -50, width: 100, height: 100)).fill()
ctx.restoreGState()

let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: "SneekyNight/Assets.xcassets/AppIcon.appiconset/icon.png"))
print("icon written")
