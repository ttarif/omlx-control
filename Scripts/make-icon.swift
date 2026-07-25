import AppKit

// Renders a macOS app icon: rounded-rect gradient + memorychip SF Symbol glyph.
func makeIcon(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext

    // Circular background with vertical gradient (indigo → teal)
    let rect = CGRect(x: size * 0.05, y: size * 0.05, width: size * 0.9, height: size * 0.9)
    let path = CGPath(ellipseIn: rect, transform: nil)
    ctx.addPath(path)
    ctx.clip()

    let colors = [
        NSColor(calibratedRed: 0.36, green: 0.30, blue: 0.92, alpha: 1).cgColor, // indigo
        NSColor(calibratedRed: 0.13, green: 0.70, blue: 0.78, alpha: 1).cgColor  // teal
    ] as CFArray
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(grad,
                           start: CGPoint(x: 0, y: size),
                           end: CGPoint(x: size, y: 0),
                           options: [])

    // Glyph: memorychip symbol, white, centered
    let cfg = NSImage.SymbolConfiguration(pointSize: size * 0.5, weight: .semibold)
    if let sym = NSImage(systemSymbolName: "memorychip", accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) {
        let tinted = NSImage(size: sym.size)
        tinted.lockFocus()
        NSColor.white.set()
        let r = NSRect(origin: .zero, size: sym.size)
        sym.draw(in: r)
        r.fill(using: .sourceAtop)
        tinted.unlockFocus()

        let gs = tinted.size
        let scale = (size * 0.46) / max(gs.width, gs.height)
        let dw = gs.width * scale, dh = gs.height * scale
        tinted.draw(in: NSRect(x: (size - dw)/2, y: (size - dh)/2, width: dw, height: dh),
                    from: .zero, operation: .sourceOver, fraction: 0.95)
    }

    img.unlockFocus()
    return img
}

func writePNG(_ image: NSImage, to path: String, px: Int) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: px, height: px),
               from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
}

let outDir = CommandLine.arguments[1]
let sizes = [16, 32, 64, 128, 256, 512, 1024]
for px in sizes {
    let icon = makeIcon(size: CGFloat(px))
    writePNG(icon, to: "\(outDir)/icon_\(px).png", px: px)
    print("wrote icon_\(px).png")
}
