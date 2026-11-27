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
        let key=app.descendants(matching:.any).matching(identifier:"qj.q").firstMatch
        func attach(_ name:String) {
            let shot=XCTAttachment(screenshot:XCUIScreen.main.screenshot())
            shot.name=name;shot.lifetime = .keepAlways;add(shot)
        }
        attach("系统首次选择的键盘")
        for _ in 0..<4 where !key.waitForExistence(timeout:2) {
            let globe=app.buttons.matching(NSPredicate(format:"label IN %@",["Next keyboard","下一个键盘","下一键盘"])).firstMatch
            if globe.exists {globe.tap()} else {
                app.coordinate(withNormalizedOffset:CGVector(dx:0.07,dy:0.954)).tap()
            }
        }
        guard key.waitForExistence(timeout:10) else {
            XCTFail("Custom extension is not visible: "+app.debugDescription);return
        }
        func verify(_ name:String) {
            let screenshot=XCUIScreen.main.screenshot()
            let attachment=XCTAttachment(screenshot:screenshot);attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)
            let im=screenshot.image,box=key.frame
            let point=CGPoint(x:box.minX+box.width*0.25,y:box.midY+box.height*0.24)
            var pixel=[UInt8](repeating:0,count:4)
            let ctx=CGContext(data:&pixel,width:1,height:1,bitsPerComponent:8,bytesPerRow:4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
            let r=CGRect(x:point.x*im.scale,y:point.y*im.scale,width:1,height:1)
            guard let crop=im.cgImage?.cropping(to:r) else{XCTFail("Key outside screenshot");return}
            ctx.draw(crop,in:CGRect(x:0,y:0,width:1,height:1))
            XCTAssertLessThan(pixel[0],150,name)
            XCTAssertGreaterThan(pixel[0],35,name)
        }
        verify("打开键盘")
        // Switch to Flypy using the extension's own toolbar and verify a real conversion.
        let mode=app.descendants(matching:.any).matching(identifier:"qj.scheme").firstMatch
        if mode.exists && mode.label == "全拼" { mode.tap() }
        for letter in ["n","i","h","c"] {
            app.descendants(matching:.any).matching(identifier:"qj."+letter).firstMatch.tap()
        }
        let first=app.descendants(matching:.any).matching(identifier:"qj.pick0").firstMatch
        XCTAssertTrue(first.waitForExistence(timeout:4))
        first.tap()
        XCTAssertEqual(field.value as? String,"你好")
        attach("双拼输入完成")
        key.tap()
        let settings=XCUIApplication(bundleIdentifier:"com.apple.Preferences")
        settings.activate()
        app.activate()
        XCTAssertTrue(key.waitForExistence(timeout:10))
        verify("返回应用")
        Thread.sleep(forTimeInterval:0.4)
        verify("返回稳定画面")
    }
}
