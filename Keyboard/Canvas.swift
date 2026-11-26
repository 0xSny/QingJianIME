import UIKit

struct Cap {
    let id: String
    let box: CGRect
    let face: String
    let sub: String
}
final class Finger {
    let cap: Cap, start: CGPoint, time = CACurrentMediaTime()
    var done = false, moved = false, steps = 0
    var timer: Timer?
    init(_ c: Cap, _ p: CGPoint) { cap = c; start = p }
}
final class Canvas: UIInputView, UIInputViewAudioFeedback {
    weak var owner: KeyboardController?
    var dark = false, mode = 0, upper = false, locked = false, grid = false
    var filter = 0, offset: CGFloat = 0, paste = false
    var caps = [Cap](), slots = [(Int,CGRect)](), fingers = [UITouch:Finger]()
    var focused: Cap?, stamp = 0, lastShift = 0.0
    let click = KeyClick()
    let haptic = UIImpactFeedbackGenerator(style: .rigid)
    var opt: Options { owner?.settings.value ?? Options() }
    var enableInputClicksWhenVisible: Bool { true }
    let hints = ["q":"iu","w":"ei","e":"e","r":"uan","t":"ue üe","y":"un","u":"u","i":"i","o":"o uo","p":"ie","a":"a","s":"ong iong","d":"ai","f":"en","g":"eng","h":"ang","j":"an","k":"ing uai","l":"iang uang","z":"ou","x":"ia ua","c":"ao","v":"ui ü","b":"in","n":"iao","m":"ian"]
    let secondary = Dictionary(uniqueKeysWithValues: zip(Array("qwertyuiopasdfghjklzxcvbnm").map(String.init),Array("1234567890@#$%&*-+()!?，。；：").map(String.init)))
    var ink: UIColor { dark ? .white : UIColor(white: 0.12, alpha: 1) }
    var base: UIColor { UIColor(white: dark ? 0.12 : opt.appearance == 2 ? 0.96 : 0.86, alpha: 1) }
    var face: UIColor { UIColor(white: dark ? 0.28 : 1, alpha: 1) }
    override func didMoveToWindow() { super.didMoveToWindow(); owner?.refreshTheme(); if window == nil { stop() } }
    func stop() { fingers.values.forEach { $0.timer?.invalidate() }; fingers.removeAll(); focused = nil; setNeedsDisplay() }
    func label(_ s: String, in r: CGRect, size: CGFloat, color: UIColor, bold: Bool = false) {
        let font = UIFont.systemFont(ofSize: max(5,size), weight: bold ? .medium : .regular)
        let attrs: [NSAttributedString.Key:Any] = [.font:font,.foregroundColor:color]
        let str = s as NSString, width = str.size(withAttributes: attrs).width
        guard r.width > 0 else { return }
        let adjusted = min(1,(r.width-2)/max(1,width))
        let f = font.withSize(max(5,font.pointSize*adjusted))
        let a: [NSAttributedString.Key:Any] = [.font:f,.foregroundColor:color]
        let sz = str.size(withAttributes:a)
        str.draw(at: CGPoint(x:r.midX-sz.width/2,y:r.midY-sz.height/2),withAttributes:a)
    }
    func build() {
        caps.removeAll(keepingCapacity:true); slots.removeAll(keepingCapacity:true)
        let w=bounds.width, top: CGFloat=42, h=max(1,(bounds.height-top)/4)
        guard w>0 else { return }
        let area = w * (opt.hand == 0 ? 1 : 0.83), left = opt.hand == 2 ? w-area : 0
        func cap(_ s:String,_ title:String,_ x:CGFloat,_ y:CGFloat,_ width:CGFloat,_ height:CGFloat,_ sub:String="") {
            caps.append(Cap(id:s,box:CGRect(x:x,y:y,width:width,height:height),face:title,sub:sub))
        }
        cap("settings","⚙",0,0,36,top)
        cap("expand",grid ? "⌄":"⌃",w-34,0,34,top)
        let right = w-34-(paste ? 52:0)
        if paste { cap("paste","粘贴",right,0,52,top) }
        let items = owner?.hits ?? []
        if !items.isEmpty {
            let span=max(1,right-36)
            let widths = items.map { max(48,CGFloat($0.text.count)*20+18) }
            let total = widths.reduce(0,+)
            offset = max(0,min(offset,total-span))
            var x:CGFloat=36-offset
            for (i,width) in widths.enumerated() {
                let r=CGRect(x:x,y:0,width:(i==widths.count-1 ? max(width,right-x):width),height:top)
                let visible=r.intersection(CGRect(x:36,y:0,width:span,height:top))
                if !visible.isNull { slots.append((i,visible)) }; x += width
            }
        } else { cap("scheme", opt.fly ? "小鹤双拼":"全拼",36,0,max(1,right-36),top) }
        if grid {
            let all = items.indices.filter { filter==0 || items[$0].text.count==filter }
            let start = min(max(0,Int(offset/48)),max(0,all.count-12))
            for (k,i) in all.dropFirst(start).prefix(12).enumerated() {
                cap("pick"+String(i),items[i].text,CGFloat(k%4)*w/4,top+CGFloat(k/4)*h,w/4,h)
            }
            for (j,s) in ["全部","单字","双字","三字","‹","›"].enumerated() {cap("filter"+String(j),s,CGFloat(j)*w/6,top+3*h,w/6,h)}
            return
        }
        let alpha = mode<=1
        var rows = alpha ? ["q w e r t y u i o p","a s d f g h j k l","shift z x c v b n m del"] :
            mode==2 ? ["+ 1 2 3 ¥","− 4 5 6 :","× 7 8 9 del"] :
            mode==3 ? ["， 。 ！ ？ 、 ： ； …","「」 『』 《》 “” （） 【】","@ # % & _ / del"] :
            ["😀 😂 😊 🥰 😎 👍","🎉 ❤️ 👌 🙏 ✨ 🌙","🙂 🤔 🥳 👏 💪 🌸 del"]
        rows.append(alpha ? "num sym lang globe space ' delret" : mode==2 ? "abc sym 0 . space delret" : "abc num emoji globe space delret")
        let titles=["shift":locked ? "⇪":"⇧","del":"⌫","space":"空格","lang":mode==1 ? "英/中":"中/英","globe":"◎","delret":owner?.returnTitle ?? "换行","num":"123","sym":"符","abc":"返回","emoji":"☺"]
        for (j,row) in rows.enumerated() {
            let keys=row.split(separator:" ").map(String.init)
            let inset:CGFloat = alpha && j==1 ? area/20 : 0
            let weights=keys.map { $0=="space" ? 3.6 : $0=="delret" ? 1.7 : 1.0 }
            let unit=(area-2*inset)/CGFloat(weights.reduce(0,+))
            var x=left+inset
            for (i,id) in keys.enumerated() {
                let width=CGFloat(weights[i])*unit
                var display=titles[id] ?? (upper && mode==1 ? id.uppercased() : id)
                let show=mode==0 && opt.fly && opt.hints<2 && hints[id] != nil
                if show && opt.hints==0, let digraph=["u":"sh","i":"ch","v":"zh"][id] {display += " "+digraph}
                cap(id,display,x,top+CGFloat(j)*h,width,h,show ? hints[id] ?? "" : "")
                x+=width
            }
        }
    }
    override func layoutSubviews(){super.layoutSubviews();build();setNeedsDisplay()}
    override func draw(_ rect:CGRect) {
        build();base.setFill();UIRectFill(bounds)
        let scale=window?.screen.scale ?? contentScaleFactor
        for cap in caps {
            let b=cap.box
            if b.minY==0 { label(cap.face,in:b,size:15,color:ink);continue }
            var r=b.insetBy(dx:2,dy:3)
            r.origin.x=(r.minX*scale).rounded()/scale; r.origin.y=(r.minY*scale).rounded()/scale
            UIColor(white:0,alpha:0.25).setFill();UIBezierPath(roundedRect:r.offsetBy(dx:0,dy:1),cornerRadius:5).fill()
            (focused?.id==cap.id ? UIColor.systemGray : cap.id=="delret" ? UIColor(red:0.29,green:0.49,blue:0.72,alpha:1) : face).setFill()
            UIBezierPath(roundedRect:r,cornerRadius:5).fill()
            let has = !cap.sub.isEmpty
            let primary=has ? CGRect(x:r.minX+3,y:r.minY,width:r.width-6,height:r.height*0.55):r
            label(cap.face,in:primary,size:cap.face.count==1 ? (has ? 19:22):16,color:cap.id=="delret" ? .white:ink)
            if has {
                let parts=cap.sub.split(separator:" "), lh=r.height*0.42/CGFloat(max(2,parts.count))
                for (i,s) in parts.enumerated() {
                    label(String(s),in:CGRect(x:r.minX+3,y:r.midY+CGFloat(i)*lh,width:r.width-6,height:lh),size:min(10,lh),color:ink.withAlphaComponent(0.62))
                }
            }
        }
        for (i,r) in slots where i < (owner?.hits.count ?? 0) {
            label(owner!.hits[i].text,in:r,size:18,color:ink)
            ink.withAlphaComponent(0.14).setFill();UIRectFill(CGRect(x:r.maxX-1/scale,y:10,width:1/scale,height:22))
        }
        if let f=focused,opt.bubbles,hints[f.id] != nil {
            let r=CGRect(x:min(max(0,f.box.midX-23),bounds.width-46),y:max(0,f.box.minY-28),width:46,height:48)
            face.setFill();UIBezierPath(roundedRect:r,cornerRadius:8).fill();label(f.face,in:r,size:28,color:ink)
        }
    }
    func distance(_ c:Cap,_ p:CGPoint)->CGFloat {
        let dx=(c.box.midX-p.x)/max(1,c.box.width),dy=(c.box.midY-p.y)/max(1,c.box.height)
        return dx*dx+dy*dy
    }
    func hit(_ p:CGPoint)->Cap? {
        if let (i,r)=slots.first(where:{$0.1.contains(p)}) {return Cap(id:"pick"+String(i),box:r,face:"",sub:"")}
        if let c=caps.first(where:{$0.box.contains(p)}){return c}
        return caps.filter{$0.box.minY>0}.min { distance($0,p)<distance($1,p) }
    }
    func feedback() {
        if opt.vibration>0 { haptic.impactOccurred(intensity:[0,0.3,0.65,1][opt.vibration]);haptic.prepare() }
        if opt.sound { click.play(volume:opt.volume) }
    }
    override func touchesBegan(_ touches:Set<UITouch>,with event:UIEvent?) {
        build()
        for t in touches.sorted(by:{$0.timestamp<$1.timestamp}) {
            let p=t.location(in:self);guard let c=hit(p) else {continue}
            for f in fingers.values where !f.done && !f.moved { finish(f);f.timer?.invalidate() }
            let f=Finger(c,p);fingers[t]=f;feedback();stamp+=1;focused=c;setNeedsDisplay()
            if c.id=="del" {
                owner?.back(); repeatDelete(f,0.38)
            } else if c.id.hasPrefix("pick"),let i=Int(c.id.dropFirst(4)) {
                f.timer=Timer.scheduledTimer(withTimeInterval:0.55,repeats:false){ [weak self,weak f] _ in
                    guard let f,!f.done,!f.moved else{return};f.done=true;self?.owner?.forget(i)
                }
            }
        }
    }
    func repeatDelete(_ f:Finger,_ delay:Double){
        f.timer=Timer.scheduledTimer(withTimeInterval:delay,repeats:false){[weak self,weak f] _ in
            guard let self,let f,!f.done,!f.moved else{return}
            let elapsed=CACurrentMediaTime()-f.time
            self.owner?.back(word:elapsed>1.5);self.repeatDelete(f,max(0.035,0.14-elapsed*0.04))
        }
    }
    override func touchesMoved(_ touches:Set<UITouch>,with event:UIEvent?){
        for t in touches { guard let f=fingers[t],!f.done else{continue}
            let p=t.location(in:self),dx=p.x-f.start.x,dy=p.y-f.start.y
            if f.cap.id.hasPrefix("pick") && abs(dx)>=8 {
                f.timer?.invalidate();f.moved=true;offset -= p.x-t.previousLocation(in:self).x;setNeedsDisplay()
            } else if f.cap.id=="space" {
                let steps=Int(dx/opt.cursor);if steps != f.steps {owner?.cursor(steps-f.steps);f.steps=steps;f.moved=true;if opt.vibration>0 {haptic.impactOccurred(intensity:0.3)}}
            } else if f.cap.id=="del" && dx < -32 && opt.swipeDelete {
                f.timer?.invalidate();f.done=true;owner?.cancelComposition()
            } else if opt.swipe,dy < -18,let s=secondary[f.cap.id] { f.done=true;owner?.literal(s) }
        }
    }
    func finish(_ f:Finger){
        guard !f.done,!f.moved else{return};f.done=true
        let id=f.cap.id
        if id.hasPrefix("pick"),let i=Int(id.dropFirst(4)){owner?.pick(i);return}
        if id.hasPrefix("filter"),let i=Int(id.dropFirst(6)){if i<4{filter=i;offset=0}else{offset += i==4 ? -576:576};setNeedsDisplay();return}
        switch id {
        case "del": break
        case "settings": owner?.drawer()
        case "scheme": owner?.settings.value.fly.toggle()
        case "expand":grid.toggle();offset=0
        case "paste":owner?.pasteText()
        case "space":owner?.space()
        case "delret":owner?.enter()
        case "globe":owner?.advanceToNextInputMode()
        case "lang","abc","num","sym","emoji":
            owner?.cancelComposition();mode=id=="lang" ? (mode==1 ? 0:1):id=="num" ? 2:id=="sym" ? 3:id=="emoji" ? 4:0
        case "shift":
            if mode==0 {mode=1}
            let now=CACurrentMediaTime();locked=now-lastShift<0.3 && !locked;upper=locked || !upper;lastShift=now
        default:
            if mode==0 && (hints[id] != nil || id=="'") {
                let nearby=caps.filter{hints[$0.id] != nil}.sorted{distance($0,f.start)<distance($1,f.start)}.prefix(3)
                let nearest=nearby.first.map{distance($0,f.start)} ?? 0
                let costs=nearby.map{UInt8(min(255,max(0,(distance($0,f.start)-nearest)*(opt.fly ? 80:36))))}
                owner?.letter(id,Array(nearby.compactMap{$0.id.utf8.first})+costs)
            } else {owner?.literal(mode==1 && upper ? id.uppercased():id);if !locked {upper=false}}
        }
        setNeedsDisplay()
    }
    func release(_ touches:Set<UITouch>,commit:Bool){
        for t in touches {guard let f=fingers.removeValue(forKey:t) else{continue};f.timer?.invalidate();if commit {finish(f)}
            if fingers.isEmpty {let mark=stamp;DispatchQueue.main.asyncAfter(deadline:.now()+max(0,0.035-CACurrentMediaTime()+f.time)){[weak self] in
                guard let self,self.stamp==mark else{return};self.focused=nil;self.setNeedsDisplay()
            }}
        }
    }
    override func touchesEnded(_ touches:Set<UITouch>,with event:UIEvent?){release(touches,commit:true)}
    override func touchesCancelled(_ touches:Set<UITouch>,with event:UIEvent?){release(touches,commit:false)}
}
