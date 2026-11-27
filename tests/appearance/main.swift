func expect(_ expected: Bool, option: Int = 0, display: PaletteStyle = .unknown,
            host: PaletteStyle = .unknown, scene: PaletteStyle = .unknown,
            window: PaletteStyle = .unknown, view: PaletteStyle = .unknown,
            attached: Bool = true, previous: Bool = true) {
    precondition(Appearance.dark(option: option, display: display, host: host,
        scene: scene, window: window, view: view, attached: attached, previous: previous) == expected)
}
expect(true, display: .dark, host: .light, scene: .light, window: .light, view: .light)
expect(true, host: .light, scene: .dark)
expect(true, view: .light, attached: false)
expect(true, host: .light)
expect(false, display: .light, scene: .light, window: .light)
expect(true, display: .light, host: .dark, previous: false)
expect(true, option: 3, display: .light, previous: false)
expect(false, option: 1, display: .dark)
expect(false, option: 2, host: .dark)
