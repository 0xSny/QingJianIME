func verify(_ host: PaletteStyle, _ scene: PaletteStyle, _ window: PaletteStyle, _ view: PaletteStyle, attached: Bool = true, previous: Bool = true, expected: Bool) {
    precondition(Appearance.dark(forcedLight: false, host: host, scene: scene, window: window, view: view, attached: attached, previous: previous) == expected)
}
verify(.unknown,.dark,.dark,.dark,expected:true)
verify(.unknown,.unknown,.unknown,.light,attached:false,expected:true)
verify(.unknown,.unknown,.unknown,.unknown,expected:true)
verify(.unknown,.light,.dark,.light,expected:true)
verify(.unknown,.dark,.dark,.light,expected:true)
verify(.light,.dark,.dark,.dark,expected:false)
verify(.unknown,.light,.light,.light,expected:false)
verify(.dark,.light,.light,.light,previous:false,expected:true)

