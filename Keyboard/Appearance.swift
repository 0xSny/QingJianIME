enum PaletteStyle { case unknown, light, dark }

enum Appearance {
    // The display tracks the user's system appearance while the remote keyboard
    // window and the text proxy can still describe the previous foreground app.
    static func dark(option: Int, display: PaletteStyle, host: PaletteStyle,
                     scene: PaletteStyle, window: PaletteStyle, view: PaletteStyle,
                     attached: Bool, previous: Bool) -> Bool {
        switch option {
        case 1, 2: return false
        case 3: return true
        default: break
        }
        if display == .dark || host == .dark { return true }
        guard attached else { return previous }
        if scene == .dark || window == .dark || view == .dark { return true }
        if display == .light || scene == .light || window == .light { return false }
        return previous
    }
}
