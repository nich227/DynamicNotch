// It draws the disk image background as a soft color field with glass tiles under the
// two icons. A glass capsule with a chevron sits between them. Nothing opaque is drawn
// where the icons sit.
//
//   swift scripts/make-dmg-background.swift <version> <minimum macos> <output directory>
//
// Writes background.png and background@2x.png, which make-dmg.sh folds into a single
// tiff so the window looks right on both kinds of display.

import AppKit

let arguments = CommandLine.arguments
guard arguments.count >= 4 else {
    FileHandle.standardError.write(
        ("usage: make-dmg-background.swift <version> <minimum macos>"
            + " <output directory>\n").data(using: .utf8)!)
    exit(1)
}
let version = arguments[1]
// read from the app being packaged rather than written here, so raising the deployment
// target cannot leave the window claiming something the app no longer supports
let minimumSystem = arguments[2]
let outputDirectory = arguments[3]

/* The window make-dmg.sh opens, and the canvas drawn behind it.

   Finder paints a background at its natural size, anchored top left, and never scales
   it: drag the window wider and the image simply runs out, leaving bare grey. So the
   canvas is drawn larger than the window and the layout is placed inside the window's
   part of it. Opened, it looks exactly composed; pulled bigger, more of the same color
   field comes into view instead of an edge.

   Everything is measured from the top left for that reason, since that corner is the
   one the window and the canvas share. */
let windowWidth: CGFloat = 600
let windowHeight: CGFloat = 400
let width: CGFloat = 1000
let height: CGFloat = 760

// where the icons land, so the art can stay out of their way
let appIcon = CGPoint(x: 150, y: 180)
let applicationsIcon = CGPoint(x: 450, y: 180)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!

func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)!
}

/* Finder draws the icon names in black in the light appearance and white in the dark
   appearance. It does not consider the picture, so the field uses middle tones that
   keep both readable. */
func drawField(_ cg: CGContext) {
    cg.drawLinearGradient(
        gradient([color(0x4f7fe6), color(0x6b63d9), color(0x8a5fd0)], [0, 0.55, 1]),
        start: CGPoint(x: 0, y: height), end: CGPoint(x: width, y: 0), options: [])

    // Soft pools of color look like light gathering behind glass.
    let pools: [(CGPoint, CGFloat, UInt32, CGFloat)] = [
        (CGPoint(x: 90, y: height - 60), 320, 0x58c7f3, 0.55),
        (CGPoint(x: 560, y: height - 330), 300, 0xe58ad0, 0.38),
        (CGPoint(x: 330, y: height - 430), 360, 0x3d6fe0, 0.45),
        (CGPoint(x: 860, y: height - 160), 340, 0x7ad9e6, 0.35),
        (CGPoint(x: 760, y: height - 640), 380, 0x9a7cf0, 0.40),
    ]
    for (center, radius, hex, alpha) in pools {
        cg.drawRadialGradient(
            gradient([color(hex, alpha), color(hex, 0)], [0, 1]),
            startCenter: center, startRadius: 0, endCenter: center, endRadius: radius,
            options: [])
    }
}

/* This draws one piece of glass. The glass has a soft shadow under it and a faint fill
   that is brighter at the top. It has a bright rim where the light comes from and a
   darker rim on the far side. The field behind it is already smooth, so the glass needs
   no blur of its own. */
func drawGlass(_ cg: CGContext, _ rect: CGRect, radius: CGFloat, strength: CGFloat = 1) {
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    cg.saveGState()
    cg.setShadow(
        offset: CGSize(width: 0, height: -8), blur: 22, color: color(0x1b1f5a, 0.28 * strength))
    cg.addPath(path)
    cg.setFillColor(color(0xffffff, 0.10 * strength))
    cg.fillPath()
    cg.restoreGState()

    cg.saveGState()
    cg.addPath(path)
    cg.clip()
    cg.drawLinearGradient(
        gradient(
            [
                color(0xffffff, 0.30 * strength), color(0xffffff, 0.06 * strength),
                color(0xffffff, 0.14 * strength),
            ], [0, 0.6, 1]),
        start: CGPoint(x: rect.midX, y: rect.maxY), end: CGPoint(x: rect.midX, y: rect.minY), options: [])
    // the highlight that sits just inside the top edge
    let sheen = CGRect(
        x: rect.minX - rect.width * 0.1, y: rect.maxY - rect.height * 0.34,
        width: rect.width * 1.2, height: rect.height * 0.5)
    cg.addEllipse(in: sheen)
    cg.clip()
    cg.drawLinearGradient(
        gradient([color(0xffffff, 0.22 * strength), color(0xffffff, 0)], [0, 1]),
        start: CGPoint(x: rect.midX, y: rect.maxY), end: CGPoint(x: rect.midX, y: sheen.minY), options: [])
    cg.restoreGState()

    // the rim: bright toward the light at the top left, dim at the bottom right
    cg.saveGState()
    let inset = rect.insetBy(dx: 0.5, dy: 0.5)
    cg.addPath(
        CGPath(
            roundedRect: inset, cornerWidth: radius - 0.5, cornerHeight: radius - 0.5,
            transform: nil))
    cg.setLineWidth(1)
    cg.replacePathWithStrokedPath()
    cg.clip()
    cg.drawLinearGradient(
        gradient(
            [
                color(0xffffff, 0.85 * strength), color(0xffffff, 0.18 * strength),
                color(0xffffff, 0.45 * strength),
            ], [0, 0.55, 1]),
        start: CGPoint(x: rect.minX, y: rect.maxY), end: CGPoint(x: rect.maxX, y: rect.minY), options: [])
    cg.restoreGState()
}

func text(_ string: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat) -> NSAttributedString {
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(srgbRed: 0.1, green: 0.1, blue: 0.35, alpha: 0.35)
    shadow.shadowBlurRadius = 3
    shadow.shadowOffset = NSSize(width: 0, height: -1)
    return NSAttributedString(
        string: string,
        attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: NSColor(white: 1, alpha: alpha),
            .shadow: shadow,
        ])
}

func draw(scale: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: width, height: height)

    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    let cg = context.cgContext

    drawField(cg)

    /* From here on, positions are given in the window's terms and turned into the
       canvas's. The two share their top left corner, so a distance down from the top is
       the same in both; the window's bottom edge is what moves. */
    let windowBottom = height - windowHeight
    func down(_ n: CGFloat) -> CGFloat { height - n }
    func up(_ n: CGFloat) -> CGFloat { windowBottom + n }

    // The island hangs from the top edge, like the island in the app.
    let island = CGRect(x: windowWidth / 2 - 72, y: down(34), width: 144, height: 34 + 20)
    cg.saveGState()
    cg.clip(to: CGRect(x: 0, y: down(34), width: windowWidth, height: 34))
    cg.setShadow(offset: CGSize(width: 0, height: -4), blur: 12, color: color(0x101040, 0.35))
    cg.addPath(CGPath(roundedRect: island, cornerWidth: 17, cornerHeight: 17, transform: nil))
    cg.setFillColor(color(0x000000))
    cg.fillPath()
    cg.restoreGState()

    // a tile of glass under each icon and its name
    let tile = CGSize(width: 156, height: 168)
    for icon in [appIcon, applicationsIcon] {
        let rect = CGRect(
            x: icon.x - tile.width / 2, y: down(icon.y + 14) - tile.height / 2,
            width: tile.width, height: tile.height)
        drawGlass(cg, rect, radius: 36)
    }

    // between them, a capsule of glass with a chevron pointing at Applications
    let capsule = CGRect(x: windowWidth / 2 - 30, y: down(appIcon.y) - 18, width: 60, height: 36)
    drawGlass(cg, capsule, radius: 18, strength: 1.15)
    cg.saveGState()
    cg.setStrokeColor(color(0xffffff, 0.95))
    cg.setLineWidth(2.6)
    cg.setLineCap(.round)
    cg.setLineJoin(.round)
    let middle = CGPoint(x: capsule.midX, y: capsule.midY)
    cg.move(to: CGPoint(x: middle.x - 9, y: middle.y))
    cg.addLine(to: CGPoint(x: middle.x + 8, y: middle.y))
    cg.move(to: CGPoint(x: middle.x + 2, y: middle.y + 6.5))
    cg.addLine(to: CGPoint(x: middle.x + 8.5, y: middle.y))
    cg.addLine(to: CGPoint(x: middle.x + 2, y: middle.y - 6.5))
    cg.strokePath()
    cg.restoreGState()

    // the instruction, under the tiles, centered
    let instruction = text("Drag DynamicNotch to Applications", size: 13, weight: .semibold, alpha: 0.96)
    instruction.draw(at: CGPoint(x: (windowWidth - instruction.size().width) / 2, y: down(322)))

    // the footer
    let versionText = text("Version \(version)", size: 10.5, weight: .medium, alpha: 0.72)
    versionText.draw(at: CGPoint(x: 28, y: up(18)))
    let requirement = text("Requires macOS \(minimumSystem)", size: 10.5, weight: .medium, alpha: 0.72)
    requirement.draw(at: CGPoint(x: windowWidth - 28 - requirement.size().width, y: up(18)))

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func write(_ rep: NSBitmapImageRep, to path: String) {
    guard let data = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write("could not encode \(path)\n".data(using: .utf8)!)
        exit(1)
    }
    do {
        try data.write(to: URL(fileURLWithPath: path))
        print("  wrote \(path) (\(rep.pixelsWide)x\(rep.pixelsHigh))")
    } catch {
        FileHandle.standardError.write("could not write \(path)\n".data(using: .utf8)!)
        exit(1)
    }
}

write(draw(scale: 1), to: "\(outputDirectory)/background.png")
write(draw(scale: 2), to: "\(outputDirectory)/background@2x.png")
