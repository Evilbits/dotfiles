import Cocoa

// The menu bar icon: frame decoding, tinting and the four animation styles. Verbatim from claude-status-bar.
extension StatusController {

    static func loadFrames() -> [NSImage] { decodePNGs(claudeSparkFramePNGs) }
    static func decodePNGs(_ list: [String]) -> [NSImage] {
        list.compactMap { Data(base64Encoded: $0).flatMap(NSImage.init(data:)) }
    }

    func iconImage(color: NSColor?, frame: Int) -> NSImage {
        let key = "\(animStyle.rawValue)|\(frame)|\(color == nil)"
        if let cached = iconCache[key] { return cached }
        let img = flattened(buildIconImage(color: color, frame: frame))
        iconCache[key] = img
        return img
    }

    func flattened(_ img: NSImage) -> NSImage {
        let s = img.size
        guard s.width > 0, s.height > 0,
              let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: Int(s.width * 2), pixelsHigh: Int(s.height * 2),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                         isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0) else { return img }
        rep.size = s
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        img.draw(in: NSRect(origin: .zero, size: s), from: .zero, operation: .sourceOver, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()
        let out = NSImage(size: s)
        out.addRepresentation(rep)
        out.isTemplate = img.isTemplate
        return out
    }

    func buildIconImage(color: NSColor?, frame: Int) -> NSImage {
        if animStyle == .web { return tint(frames, color: color, frame: frame) }
        if animStyle == .crab { return crabIcon(color: color, frame: frame) }
        if animStyle == .mark { return markIcon(color: color, frame: frame) }
        let i = (frame / codeSub) % codeGlyphs.count
        let local = (CGFloat(frame % codeSub) + 0.5) / CGFloat(codeSub) // 0…1 within this glyph
        // Scale envelope per glyph: rise, hold at peak, fall, so each lands before the swap.
        let env: CGFloat
        if local < 0.30 { let u = local / 0.30; env = u * u * (3 - 2 * u) }
        else if local > 0.70 { let u = (1 - local) / 0.30; env = u * u * (3 - 2 * u) }
        else { env = 1 }
        let scale = codeDip + (codePeaks[i] - codeDip) * env
        return codeIcon(color: color, glyph: i, scale: scale)
    }

    // nil color => adaptive template image (system draws it black/white per the menu bar).
    func codeIcon(color: NSColor?, glyph: Int, scale: CGFloat) -> NSImage {
        let s: CGFloat = 18
        guard glyph < codeGlyphMasks.count else { return NSImage(size: NSSize(width: s, height: s)) }
        let mask = codeGlyphMasks[glyph]
        let img = NSImage(size: NSSize(width: s, height: s), flipped: false) { _ in
            let dw = s * scale
            let r = NSRect(x: (s - dw) / 2, y: (s - dw) / 2, width: dw, height: dw)
            if let c = color {
                c.setFill(); r.fill()
                mask.draw(in: r, from: .zero, operation: .destinationIn, fraction: 1.0)
            } else {
                mask.draw(in: r, from: .zero, operation: .sourceOver, fraction: 1.0)
            }
            return true
        }
        img.isTemplate = (color == nil)
        return img
    }

    // Rasterize a single glyph into a centered 60x60 alpha mask filling ~92%.
    static func glyphMask(_ g: String) -> NSImage {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 180), .foregroundColor: NSColor.black,
        ]
        let str = NSAttributedString(string: g, attributes: attrs)
        let sz = str.size()
        let big = NSImage(size: sz, flipped: false) { _ in str.draw(at: .zero); return true }
        guard let rep = big.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)) else {
            return NSImage(size: NSSize(width: 60, height: 60))
        }
        let w = rep.pixelsWide, h = rep.pixelsHigh, data = rep.bitmapData!
        var minx = w, miny = h, maxx = -1, maxy = -1
        for y in 0..<h { for x in 0..<w where data[(y*w+x)*4+3] > 20 {
            minx = min(minx, x); maxx = max(maxx, x); miny = min(miny, y); maxy = max(maxy, y)
        }}
        guard maxx >= 0 else { return NSImage(size: NSSize(width: 60, height: 60)) }
        let bw = CGFloat(maxx - minx + 1), bh = CGFloat(maxy - miny + 1)
        let out: CGFloat = 60, fill = out * 0.92
        let scale = fill / max(bw, bh)
        let dw = bw * scale, dh = bh * scale
        // NSBitmapImageRep origin is top-left; convert the bbox to bottom-left for drawing.
        let srcRect = NSRect(x: CGFloat(minx), y: CGFloat(h - maxy - 1), width: bw, height: bh)
        return NSImage(size: NSSize(width: out, height: out), flipped: false) { _ in
            big.draw(in: NSRect(x: (out - dw)/2, y: (out - dh)/2, width: dw, height: dh),
                     from: srcRect, operation: .sourceOver, fraction: 1.0)
            return true
        }
    }

    func restingIcon(color: NSColor?) -> NSImage {
        if animStyle == .crab { return crabIcon(color: color, frame: 0) }
        if animStyle == .mark, let logo = logoSet.first {
            return markLayer(logo, color: color, scale: markSparkScale)
        }
        return tint(logoSet.isEmpty ? frames : logoSet, color: color, frame: 0)
    }

    func markLayer(_ mask: NSImage, color: NSColor?, scale: CGFloat) -> NSImage {
        let s: CGFloat = 18, d = s * scale
        let r = NSRect(x: (s - d) / 2, y: (s - d) / 2, width: d, height: d)
        let scaled = NSImage(size: NSSize(width: s, height: s), flipped: false) { _ in
            mask.draw(in: r, from: .zero, operation: .sourceOver, fraction: 1.0)
            return true
        }
        let img = NSImage(size: NSSize(width: s, height: s), flipped: false) { rect in
            if let c = color {
                c.setFill()
                rect.fill()
                scaled.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1.0)
            } else {
                scaled.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
            }
            return true
        }
        img.isTemplate = (color == nil)
        return img
    }

    func markIcon(color: NSColor?, frame: Int) -> NSImage {
        guard frame >= 0, frame < markSequence.count else { return restingIcon(color: color) }
        let step = markSequence[frame]
        guard let strip = markFrames[step.strip], step.frame < strip.count else {
            return NSImage(size: NSSize(width: 18, height: 18))
        }
        var sparkAlpha: CGFloat = 0
        if step.strip == "en110", step.frame < markFadeFrames {
            sparkAlpha = 1 - (CGFloat(step.frame) + 1) / CGFloat(markFadeFrames)
        } else if step.strip == "ex40" {
            let tail = strip.count - step.frame - 1
            if tail < markFadeFrames { sparkAlpha = 1 - CGFloat(tail) / CGFloat(markFadeFrames) }
        }
        let dots = markLayer(strip[step.frame], color: color, scale: markDotScale)
        guard sparkAlpha > 0, let logo = logoSet.first else { return dots }
        let spark = markLayer(logo, color: color, scale: markSparkScale)
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            dots.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1 - sparkAlpha)
            spark.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: sparkAlpha)
            return true
        }
        img.isTemplate = (color == nil)
        return img
    }

    // nil color (System) => adaptive shaded template (see adaptiveCrabFrame in CrabRender.swift);
    // non-nil (Orange) => the original full-color sprite, drawn as-is.
    func crabIcon(color: NSColor?, frame: Int) -> NSImage {
        guard !crabFrames.isEmpty else { return NSImage(size: NSSize(width: 18, height: 18)) }
        let pool = color == nil ? crabTemplateFrames : crabFrames
        let src = pool[frame % pool.count]
        let rep = src.representations.first
        let pw = CGFloat(rep?.pixelsWide ?? Int(src.size.width))
        let ph = CGFloat(rep?.pixelsHigh ?? Int(src.size.height))
        let h: CGFloat = 18, w = (ph > 0 ? h * (pw / ph) : h)
        let img = NSImage(size: NSSize(width: w, height: h), flipped: false) { rect in
            src.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
            return true
        }
        img.isTemplate = (color == nil)
        return img
    }

    func dotIcon(color: NSColor?) -> NSImage {
        let s: CGFloat = 18, d: CGFloat = 9
        let img = NSImage(size: NSSize(width: s, height: s), flipped: false) { _ in
            (color ?? .systemYellow).setFill()
            NSBezierPath(ovalIn: NSRect(x: (s - d) / 2, y: (s - d) / 2, width: d, height: d)).fill()
            return true
        }
        img.isTemplate = (color == nil)
        return img
    }

    // Paint `color` through a frame mask's alpha (destinationIn) so frames recolor.
    func tint(_ set: [NSImage], color: NSColor?, frame: Int) -> NSImage {
        let s: CGFloat = 18
        guard !set.isEmpty else { return NSImage(size: NSSize(width: s, height: s)) }
        let mask = set[frame % set.count]
        let img = NSImage(size: NSSize(width: s, height: s), flipped: false) { rect in
            if let c = color {
                c.setFill()
                rect.fill()
                mask.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1.0)
            } else {
                mask.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
            }
            return true
        }
        img.isTemplate = (color == nil) // nil => adaptive black/white in the menu bar
        return img
    }
}
