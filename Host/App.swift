import SwiftUI
@main struct QingJian: App {
    @StateObject var settings = Settings()
    @State var sample = ""
    var body: some Scene {
        WindowGroup {
            NavigationView {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("在这里试打「你好世界」", text: $sample).textFieldStyle(.roundedBorder).padding(.horizontal)
                    Text("在「设置 → 通用 → 键盘 → 键盘」中添加清简，再用地球键切换。").font(.footnote).padding(.horizontal)
                    if !settings.shared { Text("独立沙盒模式 · 请在键盘的设置抽屉里调节手感。").font(.footnote).padding(.horizontal) }
                    Controls(model: settings, learned:settings.learned, clear:settings.shared ? {settings.value.resetSerial += 1}:nil)
                }.navigationTitle("清简输入法")
            }.navigationViewStyle(.stack)
        }
    }
}
