import SwiftUI
import Darwin

struct Options: Codable, Equatable {
    var fly = false, hints = 1, expanded = false, vibration = 2
    var sound = true, bubbles = true, swipe = true, doubleSpace = true, swipeDelete = true
    var resetSerial = 0
    var volume = 0.75
    var height = 268.0, hand = 0, fuzzy = 0, spatial = 1.0, cursor = 14.0
    var clipboard = false, appearance = 0, mixedSpace = false
    var phrases = [String:String]()
}
final class Settings: ObservableObject {
    static let group = "group.com.custom.ime"
    static let signal = "com.custom.ime.preferences"
    @Published private(set) var shared = false
    private var db = UserDefaults.standard
    @Published var value = Options() {
        didSet {
            guard !loading, let d = try? JSONEncoder().encode(value) else { return }
            UserDefaults.standard.set(d, forKey: "options.v1")
            if shared { db.set(d,forKey:"options.v1") }
            if shared { db.synchronize(); notify_post(Self.signal) }
        }
    }
    func copyOptions() -> Bool {
        guard let data = try? JSONEncoder().encode(value) else { return false }
        UIPasteboard.general.string = "QJSettings1:" + data.base64EncodedString()
        return true
    }
    func importOptions() -> Bool {
        let prefix = "QJSettings1:"
        guard let text = UIPasteboard.general.string, text.hasPrefix(prefix),
              let data = Data(base64Encoded: String(text.dropFirst(prefix.count))),
              var incoming = try? JSONDecoder().decode(Options.self, from:data),
              (0...3).contains(incoming.appearance), (0...3).contains(incoming.vibration),
              (0...2).contains(incoming.hand), (0...2).contains(incoming.hints),
              (0...1).contains(incoming.volume), (0...1.5).contains(incoming.spatial),
              (215...345).contains(incoming.height), (6...30).contains(incoming.cursor) else { return false }
        incoming.resetSerial=value.resetSerial
        incoming.phrases=value.phrases.merging(incoming.phrases){ _,new in new }
        value=incoming
        return true
    }
    @Published private(set) var learned = 0
    func report(_ n: Int) {
        guard db.integer(forKey:"learned.count") != n else {return}
        learned=n;db.set(n,forKey:"learned.count");if shared {db.synchronize();notify_post(Self.signal)}
    }
    private var token: Int32 = 0
    private var loading = false
    init(allowShared: Bool = true) {
        reload()
        setSharedAccess(allowShared)
    }
    func setSharedAccess(_ allowed: Bool) {
        let container = allowed ? FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:Self.group) : nil
        let useGroup = container.map {FileManager.default.isWritableFile(atPath:$0.path)} ?? false
        guard useGroup != shared else {return}
        if shared {notify_cancel(token)}
        db = useGroup ? (UserDefaults(suiteName:Self.group) ?? .standard) : .standard
        shared = useGroup
        if shared {
            db.synchronize()
            if db.data(forKey:"options.v1") == nil, let local=UserDefaults.standard.data(forKey:"options.v1") {
                db.set(local,forKey:"options.v1");db.synchronize();notify_post(Self.signal)
            }
            notify_register_dispatch(Self.signal,&token,.main) { [weak self] _ in self?.reload() }
        }
        reload()
    }
    deinit { if shared { notify_cancel(token) } }
    func reload() {
        if shared { db.synchronize() }
        let n=db.integer(forKey:"learned.count"); if n != learned {learned=n}
        guard let d=db.data(forKey:"options.v1"),
              let saved=try? JSONSerialization.jsonObject(with:d) as? [String:Any],
              let defaults=try? JSONEncoder().encode(Options()),
              var fields=try? JSONSerialization.jsonObject(with:defaults) as? [String:Any] else{return}
        fields.merge(saved){_,new in new}
        guard let data=try? JSONSerialization.data(withJSONObject:fields),
              let v=try? JSONDecoder().decode(Options.self,from:data),v != value else{return}
        if shared {UserDefaults.standard.set(d,forKey:"options.v1")}
        loading = true; value = v; loading = false
    }
}
struct Controls: View {
    @ObservedObject var model: Settings
    var extensionMode = false
    var learned = 0
    var clear: (() -> Void)?
    @State private var code = ""
    @State private var phrase = ""
    @State private var confirm = false
    @State private var transferStatus = ""
    let groups = ["zh/z","ch/c","sh/s","n/l","f/h","l/r","an/ang","en/eng","in/ing","ian/iang","uan/uang"]
    func picker(_ title: String, _ labels: [String], _ selection: Binding<Int>) -> some View {
        Picker(title, selection: selection) { ForEach(labels.indices, id: \.self) { Text(labels[$0]).tag($0) } }.pickerStyle(.menu)
    }
    var body: some View {
        Form {
            Section("输入方案") {
                Toggle("小鹤双拼", isOn: $model.value.fly)
                picker("键面助记", ["完整","极简","隐藏"], $model.value.hints)
                Toggle("展开读音", isOn: $model.value.expanded)
                picker("外观", ["跟随系统","清爽浅色","纯净亮白","固定深色"], $model.value.appearance)
            }
            Section("手感") {
                picker("触感", ["关闭","轻微","清脆","强劲"], $model.value.vibration)
                Toggle("按键音", isOn: $model.value.sound)
                if model.value.sound { Text("按键音量　\(Int(model.value.volume*100))%"); Slider(value: $model.value.volume, in: 0...1) }
                Toggle("放大气泡", isOn: $model.value.bubbles)
                Toggle("上滑输入副标", isOn: $model.value.swipe)
                Toggle("左滑退格清空", isOn: $model.value.swipeDelete)
                Toggle("双击空格句号", isOn: $model.value.doubleSpace)
                Toggle("中英之间加空格", isOn: $model.value.mixedSpace)
                Toggle("剪贴板提示", isOn: $model.value.clipboard)
            }
            Section("布局与纠错") {
                Text("键盘高度　\(Int(model.value.height)) pt")
                Slider(value: $model.value.height, in: 215...345)
                Button("恢复默认高度") { model.value.height = 268 }
                picker("单手模式", ["完整","居左","居右"], $model.value.hand)
                Text("移动一格光标　\(Int(model.value.cursor)) pt")
                Slider(value: $model.value.cursor, in: 6...30)
                Text("邻键纠错　\(Int(model.value.spatial * 100))%")
                Slider(value: $model.value.spatial, in: 0...1.5)
                DisclosureGroup("模糊音") {
                    ForEach(groups.indices, id: \.self) { i in
                        Toggle(groups[i], isOn: Binding(get: { model.value.fuzzy & (1 << i) != 0 }, set: { on in
                            if on { model.value.fuzzy |= 1 << i } else { model.value.fuzzy &= ~(1 << i) }
                        }))
                    }
                }
            }
            if let clear {
                Section("自学习") {
                    Text("已学词条　\(learned)")
                    Button("清空自学习词库", role: .destructive) { confirm = true }
                        .confirmationDialog("清空全部已学词条？", isPresented: $confirm) { Button("清空", role: .destructive, action: clear) }
                }
            }
            Group {
                Section("同步设置和短语") {
                    if extensionMode {
                        Button("从剪贴板导入设置和短语") {
                            transferStatus = model.importOptions() ? "已应用到当前键盘" : "请先在宿主复制设置，并允许键盘访问剪贴板"
                        }
                    } else {
                        Button("复制设置和短语") { transferStatus = model.copyOptions() ? "已复制，在键盘设置中点导入" : "复制失败" }
                    }
                    if !transferStatus.isEmpty { Text(transferStatus).font(.footnote) }
                }
            }
            Section("快捷短语") {
                if !extensionMode {
                    TextField("字母编码", text: $code).autocapitalization(.none)
                    TextField("展开文本", text: $phrase)
                    Button("保存短语") {
                        model.value.phrases[code.lowercased()] = phrase; code = ""; phrase = ""
                    }.disabled(code.range(of: "^[a-zA-Z]+$", options: .regularExpression) == nil || phrase.isEmpty)
                }
                ForEach(model.value.phrases.keys.sorted(), id: \.self) { k in
                    HStack { Text(k); Text(model.value.phrases[k] ?? ""); Spacer(); Button("删除") { model.value.phrases.removeValue(forKey: k) } }
                }
                if !model.shared {
                    if extensionMode {
                        Button("从剪贴板导入短语") {
                            guard let s = UIPasteboard.general.string, s.hasPrefix("QJ1:"), let d = Data(base64Encoded: String(s.dropFirst(4))),
                                  let p = try? JSONDecoder().decode([String:String].self, from: d) else { return }
                            model.value.phrases.merge(p) { _, new in new }
                        }
                    } else {
                        Button("复制短语到键盘") {
                            if let d = try? JSONEncoder().encode(model.value.phrases) { UIPasteboard.general.string = "QJ1:" + d.base64EncodedString() }
                        }
                    }
                }
            }
        }
    }
}
