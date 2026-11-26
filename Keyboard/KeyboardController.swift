import UIKit
import SwiftUI
import Combine

final class KeyboardController: UIInputViewController {
    let settings = Settings()
    private let queue = DispatchQueue(label:"com.custom.ime.decode",qos:.userInteractive)
    private var decoder: QDecoder?, ticket: UInt64 = 0
    private var observation: AnyCancellable?, heightRule: NSLayoutConstraint?
    private var options = Options()
    private var raw = Data(), taps = Data(), previous = "", learnedText = "", learnedReading = ""
    private var undoText = "", undoContext: String?, lastSpace = 0.0
    private var document: UUID?, editing = false, expectedContext: String?
    private var board: Canvas!, panel: UIHostingController<AnyView>?
    private var clipboardVersion = -1
    var hits = [QHit]()
    var returnTitle: String {
        switch textDocumentProxy.returnKeyType {
        case .send: return "发送";case .search,.google,.yahoo: return "搜索";case .go: return "前往";case .done: return "完成";default:return "换行"
        }
    }
    override func loadView() {
        board=Canvas(frame:.zero,inputViewStyle:.keyboard);board.allowsSelfSizing=true
        board.isMultipleTouchEnabled=true;board.owner=self;board.isOpaque=true
        self.inputView=board
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        let c=board.heightAnchor.constraint(equalToConstant:settings.value.height);c.priority = .defaultHigh;c.isActive=true;heightRule=c
        observation=settings.$value.sink { [weak self] value in
            DispatchQueue.main.async { self?.apply(value) }
        }
        for name in [UIScene.didActivateNotification,UIScene.willEnterForegroundNotification,UIWindow.didBecomeKeyNotification] {
            NotificationCenter.default.addObserver(self,selector:#selector(resumeTheme),name:name,object:nil)
        }
        let path=Bundle.main.path(forResource:"lex",ofType:"bin") ?? ""
        let dir=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0]
        queue.async { [weak self] in
            try? FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
            let engine=QDecoder(lex:path,storage:dir.appendingPathComponent("learning.v1").path)
            DispatchQueue.main.async { self?.decoder=engine;self?.search() }
        }
        board.haptic.prepare()
    }
    func apply(_ v:Options) {
        let changed=options.fly != v.fly;options=v
        if changed {cancelComposition()}
        heightRule?.constant=v.height;board.setNeedsLayout();refreshTheme();search()
    }
    @objc func resumeTheme(){refreshTheme();DispatchQueue.main.async { [weak self] in self?.refreshTheme() }}
    func refreshTheme() {
        guard let b=board else{return}
        let appearance=textDocumentProxy.keyboardAppearance
        let traits=[b.window?.windowScene?.traitCollection.userInterfaceStyle,b.window?.traitCollection.userInterfaceStyle,b.traitCollection.userInterfaceStyle]
        let style=traits.compactMap{$0}.first{$0 != .unspecified}
        var dark=b.dark
        if settings.value.appearance != 0 {dark=false}
        else if appearance == .dark {dark=true}
        else if appearance == .light {dark=false}
        else if let style {dark=style == .dark}
        CATransaction.begin();CATransaction.setDisableActions(true)
        b.dark=dark;b.backgroundColor=b.base;b.setNeedsDisplay()
        panel?.overrideUserInterfaceStyle=dark ? .dark:.light
        CATransaction.commit()
    }
    override func traitCollectionDidChange(_ previousTraitCollection:UITraitCollection?){super.traitCollectionDidChange(previousTraitCollection);refreshTheme()}
    override func viewWillAppear(_ animated:Bool){super.viewWillAppear(animated);settings.reload();resumeTheme()}
    override func viewDidAppear(_ animated:Bool){super.viewDidAppear(animated);resumeTheme();checkClipboard()}
    override func viewDidLayoutSubviews(){super.viewDidLayoutSubviews();panel?.view.frame=board.bounds.inset(by:UIEdgeInsets(top:42,left:0,bottom:0,right:0));refreshTheme()}
    override func viewWillDisappear(_ animated:Bool){super.viewWillDisappear(animated);board.stop();if let d=decoder{queue.async{d.flush()}}}
    override func textWillChange(_ textInput:UITextInput?){super.textWillChange(textInput);refreshTheme()}
    override func textDidChange(_ textInput:UITextInput?){
        super.textDidChange(textInput);resumeTheme()
        let id=textDocumentProxy.documentIdentifier
        if let old=document,old != id {reset();previous="";undoText=""}
        document=id
    }
    override func selectionDidChange(_ textInput:UITextInput?){
        super.selectionDidChange(textInput)
        if !editing && !raw.isEmpty && expectedContext != textDocumentProxy.documentContextBeforeInput {textDocumentProxy.unmarkText();reset()}
    }
    func checkClipboard(){
        guard settings.value.clipboard,hasFullAccess else{board.paste=false;return}
        let p=UIPasteboard.general
        guard p.changeCount != clipboardVersion,p.hasStrings else{return}
        clipboardVersion=p.changeCount;board.paste=true;board.setNeedsDisplay()
        let v=clipboardVersion
        DispatchQueue.main.asyncAfter(deadline:.now()+8){[weak self] in if self?.clipboardVersion==v {self?.board.paste=false;self?.board.setNeedsDisplay()}}
    }
    func pasteText(){if hasFullAccess,let s=UIPasteboard.general.string {literal(s)};board.paste=false}
    func drawer(){
        if let p=panel {p.willMove(toParent:nil);p.view.removeFromSuperview();p.removeFromParent();panel=nil;return}
        guard let d=decoder else{return}
        queue.async {let n=Int(d.count());DispatchQueue.main.async { [weak self] in self?.showPanel(n) }}
    }
    func showPanel(_ count:Int){
        guard panel==nil else{return}
        let ui=Controls(model:settings,extensionMode:true,learned:count,clear:{[weak self] in
            guard let self,let d=self.decoder else{return};self.queue.async{d.clear();d.flush()};self.drawer()
        })
        let p=UIHostingController(rootView:AnyView(ui));panel=p;addChild(p);board.addSubview(p.view);p.didMove(toParent:self);board.setNeedsLayout();refreshTheme()
    }
    func reset(){
        raw.removeAll();taps.removeAll();learnedText="";learnedReading="";hits=[];board.grid=false;board.offset=0
        ticket=decoder?.invalidate() ?? 0;board.setNeedsDisplay()
    }
    func mark(_ s:String){
        editing=true
        textDocumentProxy.setMarkedText(s,selectedRange:NSRange(location:s.utf16.count,length:0))
        expectedContext=textDocumentProxy.documentContextBeforeInput;editing=false
    }
    func cancelComposition(){if !raw.isEmpty {mark("");textDocumentProxy.unmarkText()};reset()}
    func letter(_ s:String,_ near:[UInt8]){
        guard raw.count<256,!(s=="'" && (raw.isEmpty || raw.last==39)) else{return}
        undoText="";document=textDocumentProxy.documentIdentifier
        raw.append(contentsOf:s.utf8);taps.append(contentsOf:near)
        hits=[];board.offset=0;mark(String(decoding:raw,as:UTF8.self));search()
    }
    func search(){
        guard let d=decoder else{return}
        let t=d.invalidate();ticket=t
        guard !raw.isEmpty else{return}
        let input=raw,touch=taps,o=settings.value,prev=previous
        queue.async {
            let result=d.search(input,touches:touch,fly:o.fly,fuzzy:Int32(o.fuzzy),spatial:o.spatial,previous:prev,token:t)
            DispatchQueue.main.async { [weak self] in
                guard let self,self.ticket==t else{return}
                self.hits=result
                let code=String(decoding:input,as:UTF8.self)
                if let phrase=o.phrases[code] {let h=QHit();h.text=phrase;h.reading="";h.used=input.count;self.hits.insert(h,at:0)}
                if let h=result.first,h.used==input.count,!h.reading.isEmpty {
                    if o.fly && o.expanded || !o.fly && h.reading.replacingOccurrences(of:" ",with:"")==code {self.mark(h.reading)}
                }
                self.board.setNeedsDisplay()
            }
        }
    }
    func pick(_ i:Int){
        guard hits.indices.contains(i),let d=decoder else{return}
        let h=hits[i],used=Int(h.used)
        guard used>0 && used<=raw.count else{return}
        let prev=previous
        mark(h.text);textDocumentProxy.unmarkText()
        if !h.reading.isEmpty {
            queue.async{d.learn(h.text,reading:h.reading,previous:prev,first:true)}
            learnedText+=h.text;learnedReading+=(learnedReading.isEmpty ? "":" ")+h.reading
        }
        previous=h.text;raw.removeFirst(used);taps.removeFirst(used*6);hits=[]
        if raw.isEmpty {
            if learnedText != h.text && !learnedReading.isEmpty {
                let w=learnedText,r=learnedReading;queue.async{d.learn(w,reading:r,previous:"",first:false)}
            }
            undoText=h.text;undoContext=textDocumentProxy.documentContextBeforeInput;reset()
        } else {mark(String(decoding:raw,as:UTF8.self));search()};board.setNeedsDisplay()
    }
    func forget(_ i:Int){
        guard hits.indices.contains(i),let d=decoder else{return}
        let h=hits[i],popup=UIAlertController(title:h.text,message:nil,preferredStyle:.alert)
        popup.addAction(UIAlertAction(title:"恢复默认词频",style:.destructive){[weak self] _ in self?.queue.async{d.erase(h.text,reading:h.reading)};self?.search()})
        popup.addAction(UIAlertAction(title:"取消",style:.cancel));present(popup,animated:false)
    }
    func literal(_ s:String){
        if !raw.isEmpty {if !hits.isEmpty{pick(0)};if !raw.isEmpty {textDocumentProxy.unmarkText();reset()}}
        undoText="";let prev=textDocumentProxy.documentContextBeforeInput?.last
        let gap=settings.value.mixedSpace && (prev?.unicodeScalars.first?.value ?? 0)>=0x4e00 && s.first?.isASCII==true && s.first?.isLetter==true
        textDocumentProxy.insertText((gap ? " ":"")+s)
        if ["「」","『』","《》","“”","（）","【】"].contains(s){cursor(-1)}
        previous=""
    }
    func enter(){if !raw.isEmpty {if !hits.isEmpty {pick(0)}else{textDocumentProxy.unmarkText();reset()}}else{literal("\n")}}
    func space(){
        if !raw.isEmpty {enter();lastSpace=0;return}
        let now=CACurrentMediaTime()
        if settings.value.doubleSpace && now-lastSpace<0.32,let ctx=textDocumentProxy.documentContextBeforeInput,ctx.hasSuffix(" "){
            textDocumentProxy.deleteBackward();let token=ctx.dropLast().split(separator:" ").last ?? ""
            literal(token.last?.isNumber==true || token.contains(".") || token.contains("/") ? ".":"。");lastSpace=0
        } else {literal(" ");lastSpace=now}
    }
    func cursor(_ delta:Int){if !raw.isEmpty{textDocumentProxy.unmarkText();reset()};undoText="";textDocumentProxy.adjustTextPosition(byCharacterOffset:delta)}
    func back(word:Bool=false){
        if !raw.isEmpty {raw.removeLast();taps.removeLast(6);hits=[]
            mark(String(decoding:raw,as:UTF8.self));if raw.isEmpty{textDocumentProxy.unmarkText();reset()}else{search()};return
        }
        if !undoText.isEmpty,undoContext==textDocumentProxy.documentContextBeforeInput,let d=decoder {queue.async{d.rollback()}}
        undoText="";previous=""
        let tail=textDocumentProxy.documentContextBeforeInput?.reversed().prefix(while:{$0.isASCII && $0.isLetter}).count ?? 1
        for _ in 0..<(word ? min(20,max(1,tail)):1){textDocumentProxy.deleteBackward()}
    }
}
