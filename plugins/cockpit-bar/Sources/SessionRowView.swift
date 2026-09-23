import Cocoa

// A session row as a custom view so the trailing text can pin to the true trailing edge (a plain menu-item
// title can't cross the menu's reserved shortcut/submenu-arrow column). Adapted from claude-status-bar.
// Layout: [icon] primary · secondary  <spacer>  trailing ›
final class SessionRowView: NSView {
    let id: String
    var onClick: (() -> Void)?
    private let iconView = NSImageView()
    private let spinner = NSProgressIndicator()
    private let pillView = NSImageView()
    private let nameField = NSTextField(labelWithString: "")
    private var pillNormal: NSImage?, pillSelected: NSImage?
    private let trailingField = NSTextField(labelWithString: "")
    private let chevron = NSTextField(labelWithString: "›")
    private let pad: CGFloat = 14, iconSize: CGFloat = 16, rowH: CGFloat = 24, chevronW: CGFloat = 10
    private let highlightView = NSVisualEffectView()  // system selection material = exact native highlight
    private var hovered = false
    private var iconBaseTint: NSColor?
    private var trailingBaseColor: NSColor = .secondaryLabelColor
    private var primaryText = "", secondaryText = ""

    init(id: String, width: CGFloat) {
        self.id = id
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: rowH))
        autoresizingMask = [.width]
        highlightView.material = .selection
        highlightView.state = .active
        highlightView.isEmphasized = true
        highlightView.wantsLayer = true
        highlightView.layer?.cornerRadius = 5
        highlightView.isHidden = true
        addSubview(highlightView)
        iconView.frame = NSRect(x: pad, y: (rowH - iconSize) / 2, width: iconSize, height: iconSize)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.autoresizingMask = [.maxXMargin]
        addSubview(iconView)
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isIndeterminate = true
        spinner.isDisplayedWhenStopped = false
        let spinSize = iconSize * 0.9
        spinner.frame = NSRect(x: pad + (iconSize - spinSize) / 2, y: (rowH - spinSize) / 2, width: spinSize, height: spinSize)
        spinner.autoresizingMask = [.maxXMargin]
        spinner.isHidden = true
        addSubview(spinner)
        pillView.imageScaling = .scaleNone
        pillView.autoresizingMask = [.maxXMargin]
        pillView.isHidden = true
        addSubview(pillView)
        nameField.font = .menuFont(ofSize: 0)
        nameField.textColor = .labelColor
        nameField.lineBreakMode = .byTruncatingTail
        nameField.frame = NSRect(x: pad + iconSize + 8, y: (rowH - 16) / 2, width: 160, height: 16)
        nameField.autoresizingMask = [.maxXMargin]
        addSubview(nameField)
        trailingField.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuFont(ofSize: 0).pointSize - 1, weight: .regular)
        trailingField.textColor = .secondaryLabelColor
        trailingField.alignment = .right
        trailingField.autoresizingMask = [.minXMargin]
        addSubview(trailingField)
        chevron.font = NSFont.systemFont(ofSize: NSFont.menuFont(ofSize: 0).pointSize + 1, weight: .medium)
        chevron.textColor = .tertiaryLabelColor
        chevron.alignment = .center
        chevron.frame = NSRect(x: width - pad + 2 - chevronW, y: (rowH - 18) / 2, width: chevronW, height: 18)
        chevron.autoresizingMask = [.minXMargin]
        addSubview(chevron)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(icon: NSImage?, iconTint: NSColor?, spinning: Bool, primary: String, secondary: String,
                   pill: NSImage? = nil, pillSelected: NSImage? = nil,
                   trailing: String?, trailingColor: NSColor = .secondaryLabelColor, gap: CGFloat) {
        let w = bounds.width
        // The verb pill sits between the icon and the text; the text starts after it.
        pillNormal = pill; self.pillSelected = pillSelected
        var textX = pad + iconSize + 8
        if let pill = pill {
            pillView.isHidden = false
            pillView.image = hovered ? pillSelected : pill
            pillView.frame = NSRect(x: textX, y: (rowH - pill.size.height) / 2, width: pill.size.width, height: pill.size.height)
            textX += pill.size.width + 7
        } else { pillView.isHidden = true }
        nameField.frame.origin.x = textX
        iconView.image = icon
        iconBaseTint = iconTint
        iconView.contentTintColor = hovered ? .white : iconTint
        if spinning {
            iconView.isHidden = true
            spinner.isHidden = false
            spinner.startAnimation(nil)
        } else {
            spinner.stopAnimation(nil)
            spinner.isHidden = true
            iconView.isHidden = false
        }
        primaryText = primary; secondaryText = secondary
        renderName()
        trailingBaseColor = trailingColor
        let right = chevron.frame.minX - 4
        if let trailing = trailing, !trailing.isEmpty {
            trailingField.isHidden = false
            trailingField.stringValue = trailing
            trailingField.textColor = hovered ? .white : trailingColor
            let font = trailingField.font ?? NSFont.menuFont(ofSize: 0)
            let tw = min(ceil(trailing.size(withAttributes: [.font: font]).width) + 2, w * 0.45)
            trailingField.frame = NSRect(x: right - tw, y: (rowH - 16) / 2, width: tw, height: 16)
        } else { trailingField.isHidden = true }
        let nameRight = trailingField.isHidden ? right : trailingField.frame.minX
        nameField.frame.size.width = max(40, nameRight - gap - nameField.frame.minX)
    }

    // primary in the label colour, " · secondary" dimmed; mirrored on hover, where setting textColor
    // can't restyle an attributed string.
    private func renderName() {
        let para = NSMutableParagraphStyle()
        para.lineBreakMode = .byTruncatingTail
        para.allowsDefaultTighteningForTruncation = false
        let font = NSFont.menuFont(ofSize: 0)
        let text = NSMutableAttributedString(string: primaryText, attributes: [
            .font: font, .paragraphStyle: para,
            .foregroundColor: hovered ? NSColor.white : .labelColor,
        ])
        if !secondaryText.isEmpty {
            text.append(NSAttributedString(string: (primaryText.isEmpty ? "" : " · ") + secondaryText, attributes: [
                .font: font, .paragraphStyle: para,
                .foregroundColor: hovered ? NSColor.white.withAlphaComponent(0.75) : .secondaryLabelColor,
            ]))
        }
        nameField.attributedStringValue = text
    }
    // Custom views don't get the menu's automatic hover highlight, so draw it ourselves.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }
    override func mouseEntered(with event: NSEvent) { setHover(true) }
    override func mouseExited(with event: NSEvent) { setHover(false) }
    private func setHover(_ h: Bool) {
        hovered = h
        highlightView.isHidden = !h
        renderName()
        trailingField.textColor = h ? .white : trailingBaseColor
        chevron.textColor = h ? .white : .tertiaryLabelColor
        iconView.contentTintColor = h ? .white : iconBaseTint
        if !pillView.isHidden { pillView.image = h ? pillSelected : pillNormal }
    }
    override func layout() {
        super.layout()
        highlightView.frame = bounds.insetBy(dx: 5, dy: 0)
    }
    override func mouseDown(with event: NSEvent) { onClick?() }
}
