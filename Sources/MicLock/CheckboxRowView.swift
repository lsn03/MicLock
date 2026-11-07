import AppKit

final class CheckboxRowView: NSView {
    private let label: String
    private var checked: Bool
    private let onToggle: (Bool) -> Void

    init(label: String, checked: Bool, onToggle: @escaping (Bool) -> Void) {
        self.label = label
        self.checked = checked
        self.onToggle = onToggle
        let width = max(240, Int(NSAttributedString(
            string: label,
            attributes: [.font: NSFont.menuFont(ofSize: 0)]
        ).size().width) + 50)
        super.init(frame: NSRect(x: 0, y: 0, width: CGFloat(width), height: 22))
        self.autoresizingMask = [.width]
    }

    required init?(coder: NSCoder) { fatalError() }

    private var isHover = false

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) { isHover = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent)  { isHover = false; needsDisplay = true }

    override func draw(_ dirtyRect: NSRect) {
        let highlighted = isHover || (enclosingMenuItem?.isHighlighted ?? false)
        let textColor: NSColor = highlighted ? .selectedMenuItemTextColor : .labelColor

        if highlighted {
            NSColor.selectedContentBackgroundColor.setFill()
            bounds.fill()
        }

        let font = NSFont.menuFont(ofSize: 0)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]

        if checked {
            let check = NSAttributedString(string: "✓", attributes: attrs)
            check.draw(at: NSPoint(x: 8, y: 3))
        }
        NSAttributedString(string: label, attributes: attrs).draw(at: NSPoint(x: 22, y: 3))
    }

    override func mouseUp(with event: NSEvent) {
        checked.toggle()
        onToggle(checked)
        needsDisplay = true
    }
}
