enum PaletteStyle: Int { case unknown, light, dark }
enum Appearance {
    static func dark(forcedLight: Bool, host: PaletteStyle, scene: PaletteStyle,
                     window: PaletteStyle, view: PaletteStyle, attached: Bool, previous: Bool) -> Bool {
        if forcedLight { return false }
        guard attached else { return previous }
        if host != .unknown { return host == .dark }
        // UIKit may briefly rebuild one trait environment while reattaching a remote view.
        let reported = [scene, window, view].filter { $0 != .unknown }
        guard !reported.isEmpty else { return previous }
        if reported.contains(.dark) { return true }
        return false
    }
}
