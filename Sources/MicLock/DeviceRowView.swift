import AppKit

final class DeviceRowView: NSView {
    let uid: String
    private let name: String
    private let checked: Bool
    private let isActiveDefault: Bool
    private let onClick: (String) -> Void

    init(uid: String, name: String, checked: Bool, isActiveDefault: Bool, onClick: @escaping (String) -> Void) {
        self.uid = uid
        self.name = name
        self.checked = checked
        self.isActiveDefault = isActiveDefault
        self.onClick = onClick
        super.init(frame: NSRect(x: 0, y: 0, width: 240, height: 22))
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

        // Checkmark column (native menu uses ~22pt)
        if checked {
            let check = NSAttributedString(string: "✓", attributes: attrs)
            check.draw(at: NSPoint(x: 8, y: 3))
        }

        // Name
        let nameStr = NSAttributedString(string: name, attributes: attrs)
        nameStr.draw(at: NSPoint(x: 22, y: 3))
    }

    override func mouseUp(with event: NSEvent) {
        onClick(uid)
    }
}
