import XCTest
final class ReturnTests: XCTestCase {
    func testKeyboardRemainsDarkAcrossAppSwitch() throws {
        let app=XCUIApplication()
        let prefs=XCUIApplication(bundleIdentifier:"com.apple.Preferences")
        prefs.launchArguments=["-AppleLanguages","(en)"]
        prefs.launch()
        func choose(_ labels:[String]) throws {
            let screen=prefs.frame.insetBy(dx:5,dy:55)
            func tapVisible(_ item:XCUIElement)->Bool {
                guard item.exists else{return false}
                let frame=item.frame
                let center=CGPoint(x:frame.midX,y:frame.midY)
                guard frame.width>2,frame.height>2,screen.contains(center) else{return false}
                prefs.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:center.x,dy:center.y)).tap()
                return true
            }
            print("Selecting "+labels[0])
            for _ in 0..<8 {
                for label in labels {
                    let text=prefs.staticTexts.matching(NSPredicate(format:"label == %@",label)).firstMatch

                    let cell=prefs.cells.matching(NSPredicate(format:"label BEGINSWITH[c] %@",label)).firstMatch
                    if tapVisible(cell){return}
                    let button=prefs.buttons.matching(NSPredicate(format:"label == %@ OR label BEGINSWITH[c] %@",label,label+",")).firstMatch
                    if tapVisible(button){return}
                    if text.exists && text.frame.minY>100 && tapVisible(text){return}
                }
                prefs.swipeUp()
            }
            XCTFail("Settings row missing: "+labels.joined(separator:",")+" "+prefs.debugDescription)
            throw NSError(domain:"Setup",code:1)
        }
        try choose(["General"])
        try choose(["Keyboard"])
        try choose(["Keyboards"])
        try choose(["Add New Keyboard…","Add New Keyboard...","Add New Keyboard"])
        try choose(["清简输入法","QingJian","清简","Keyboard"])
        if prefs.buttons["Done"].exists {prefs.buttons["Done"].tap()}
        app.launchArguments += ["--keyboard-return-test"]
        app.launch()
        let field=app.textFields["return.input"]
        XCTAssertTrue(field.waitForExistence(timeout:15))
        field.tap()
        func attach(_ name:String, _ shot:XCUIScreenshot) {
            let a=XCTAttachment(screenshot:shot)
            a.name=name
            a.lifetime = .keepAlways
            add(a)
        }
        let screen=app.frame
        func tap(_ x:CGFloat,_ y:CGFloat) {
            app.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:screen.width*x,dy:y)).tap()
        }

        // The extension's blue return cap appears in all schemes. Its height
        // gives the actual row pitch even when the system resizes the remote view.
        func geometry(_ shot:XCUIScreenshot) -> (bottom:CGFloat,pitch:CGFloat)? {
            guard let cg=shot.image.cgImage else {return nil}
            let scale=CGFloat(cg.width)/screen.width
            let x=Int(CGFloat(cg.width)*0.965)
            guard let strip=cg.cropping(to:CGRect(x:x,y:0,width:1,height:cg.height)),
                  let ctx=CGContext(data:nil,width:1,height:cg.height,bitsPerComponent:8,bytesPerRow:4,
                      space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue),
                  let data=ctx.data else{return nil}
            ctx.draw(strip,in:CGRect(x:0,y:0,width:1,height:cg.height))
            let bytes=data.assumingMemoryBound(to:UInt8.self)
            var start=0, length=0
            for y in cg.height/2..<cg.height {
                let j=4*y
                if abs(Int(bytes[j])-74)<10 && abs(Int(bytes[j+1])-125)<10 && abs(Int(bytes[j+2])-184)<10 {
                    if length==0 {start=y}
                    length+=1
                } else {
                    if CGFloat(length)/scale>26 {
                        return (CGFloat(start+length/2)/scale,CGFloat(length)/scale+6)
                    }
                    length=0
                }
            }
            return nil
        }
        func waitForBoard(_ seconds:TimeInterval) -> (bottom:CGFloat,pitch:CGFloat)? {
            let until=Date().addingTimeInterval(seconds)
            repeat {
                if let result=geometry(XCUIScreen.main.screenshot()) {return result}
                Thread.sleep(forTimeInterval:0.15)
            } while Date()<until
            return nil
        }
        var position=waitForBoard(4)
        for _ in 0..<4 where position==nil {
            let globe=app.buttons.matching(NSPredicate(format:"label IN %@",["Next keyboard","下一个键盘","下一键盘"])).firstMatch
            if globe.exists && !globe.frame.isEmpty {tap(globe.frame.midX/screen.width,globe.frame.midY)} else {tap(0.07,screen.height*0.954)}
            position=waitForBoard(4)
        }
        let pos=try XCTUnwrap(position,"No QingJian return key in keyboard area")
        let top=pos.bottom-3*pos.pitch
        let bar=top-pos.pitch/2-21
        func assertDark(_ name:String, _ shot:XCUIScreenshot) throws {
            attach(name,shot)
            let frame=try XCTUnwrap(geometry(shot),"Missing extension after returning")
            let im=try XCTUnwrap(shot.image.cgImage)
            let scale=CGFloat(im.width)/screen.width
            let area=CGRect(x:screen.width*0.023*scale,y:(frame.bottom-3.20*frame.pitch)*scale,width:1,height:1)
            let pixel=try XCTUnwrap(im.cropping(to:area))
            let ctx=try XCTUnwrap(CGContext(data:nil,width:1,height:1,bitsPerComponent:8,bytesPerRow:4,
                       space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue))
            ctx.draw(pixel,in:CGRect(x:0,y:0,width:1,height:1))
            let brightness=ctx.data!.assumingMemoryBound(to:UInt8.self)[0]
            print("Q key red channel at "+name+" = "+String(brightness))
            XCTAssertTrue((40...145).contains(brightness),name)
        }
        try assertDark("打开键盘",XCUIScreen.main.screenshot())
        tap(0.5,bar)
        tap(0.70,top+2*pos.pitch)
        tap(0.75,top)
        tap(0.60,top+pos.pitch)
        tap(0.40,top+2*pos.pitch)
        tap(0.53,pos.bottom)
        let converted=NSPredicate(format:"value == %@", "你好")
        let conversion=XCTNSPredicateExpectation(predicate:converted,object:field)
        XCTAssertEqual(XCTWaiter.wait(for:[conversion],timeout:5),.completed,"field: "+String(describing:field.value))
        attach("小鹤双拼输入你好",XCUIScreen.main.screenshot())
        tap(0.05,top)
        prefs.activate()
        app.activate()
        // The host foregrounds before the system reattaches the keyboard window.
        // Sample the same screenshot that first contains the extension; never refocus the field.
        let deadline=Date().addingTimeInterval(8)
        var returning=XCUIScreen.main.screenshot()
        while geometry(returning)==nil && Date()<deadline {
            Thread.sleep(forTimeInterval:0.035)
            returning=XCUIScreen.main.screenshot()
        }
        try assertDark("返回后首次可见键盘",returning)
        Thread.sleep(forTimeInterval:0.4)
        try assertDark("返回稳定画面",XCUIScreen.main.screenshot())
    }
}
