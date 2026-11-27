import XCTest
final class ReturnTests: XCTestCase {
    func testKeyboardRemainsDarkAcrossAppSwitch() throws {
        let app=XCUIApplication()
        let prefs=XCUIApplication(bundleIdentifier:"com.apple.Preferences")
        prefs.launchArguments=["-AppleLanguages","(en)"]
        prefs.launch()
        func choose(_ labels:[String]) throws {
            let item=prefs.staticTexts.matching(NSPredicate(format:"label IN %@",labels)).firstMatch
            for _ in 0..<7 {
                for label in labels {
                    let cell=prefs.cells.matching(NSPredicate(format:"label BEGINSWITH[c] %@",label)).firstMatch
                    if cell.exists && cell.isHittable {cell.tap();return}
                }
                if item.exists && item.isHittable { item.tap(); return }
                prefs.swipeUp()
            }
            XCTFail("Settings row missing: "+labels.joined(separator:",")+" "+prefs.debugDescription)
            throw NSError(domain:"Setup",code:1)
        }
        try choose(["General"])
        try choose(["Keyboard"])
        let lists=prefs.cells["KEYBOARDS"].firstMatch
        XCTAssertTrue(lists.waitForExistence(timeout:10))
        lists.tap()
        try choose(["Add New Keyboard…","Add New Keyboard...","Add New Keyboard"])
        try choose(["清简输入法","QingJian","清简"])
        if prefs.buttons["Done"].exists {prefs.buttons["Done"].tap()}
        app.launch()
        let field=app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout:15))
        field.tap()
        let key=app.descendants(matching:.any).matching(identifier:"qj.q").firstMatch
        for _ in 0..<4 where !key.waitForExistence(timeout:2) {
            let globe=app.buttons["Next keyboard"].firstMatch
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
