import SwiftUI
@main struct QingJian: App {
    @StateObject var settings = Settings()
    @Environment(\.scenePhase) private var phase
    @State var sample = ""
    var body: some Scene {
        WindowGroup {
            NavigationView {
                VStack(alignment: .leading, spacing: 8) {
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("--keyboard-return-test") {
                        ReturnTestField().frame(height:40).padding(.horizontal)
                    } else {
                    TextField("在这里试打「你好世界」", text: $sample).textFieldStyle(.roundedBorder).padding(.horizontal)
                    }
                    #else
                    TextField("在这里试打「你好世界」", text: $sample).textFieldStyle(.roundedBorder).padding(.horizontal)
                    #endif
                    Text("在「设置 → 通用 → 键盘 → 键盘」中添加清简，再用地球键切换。").font(.footnote).padding(.horizontal)
                    if !settings.shared { Text("独立沙盒模式 · 请在键盘的设置抽屉里调节手感。").font(.footnote).padding(.horizontal) }
                    Controls(model: settings, learned:settings.learned, clear:settings.shared ? {settings.value.resetSerial += 1}:nil)
                }.navigationTitle("清简输入法")
            }.navigationViewStyle(.stack).onChange(of:phase) { if $0 == .active {settings.reload()} }
        }
    }
}

#if DEBUG
private final class ChineseInputField: UITextField {
    override var textInputContextIdentifier: String? { "com.custom.ime.return-test" }
    override var textInputMode: UITextInputMode? {
        UITextInputMode.activeInputModes.first(where: { $0.primaryLanguage?.hasPrefix("zh") == true }) ?? super.textInputMode
    }
}
private struct ReturnTestField: UIViewRepresentable {
    func makeUIView(context:Context) -> UITextField {
        let field=ChineseInputField()
        field.borderStyle = .roundedRect
        field.accessibilityIdentifier = "return.input"
        field.placeholder = "输入测试"
        return field
    }
    func updateUIView(_ view:UITextField, context:Context) {}
}
#endif
