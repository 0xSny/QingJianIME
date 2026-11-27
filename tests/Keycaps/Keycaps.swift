import XCTest
import UIKit

final class Keycaps: XCTestCase {
    @MainActor func testFlypyGeometryAndRendering() throws {
        for width:CGFloat in [320,393] {
            for style in [0,1,2] {
                let board=Canvas(frame:CGRect(x:0,y:0,width:width,height:268))
                board.contentScaleFactor=3
                board.opt.fly=true
                board.opt.hints=style
                board.opt.hand=(width == 320 ? 1:0)
                board.dark=(style != 1)
                board.build()
                let letters=board.caps.filter {board.hints[$0.id] != nil}
                XCTAssertEqual(letters.count,26)
                for cap in letters {
                    XCTAssertEqual(cap.box.width,letters[0].box.width,accuracy:0.01)
                    XCTAssertEqual(cap.face,cap.id.uppercased())
                    let center=CGPoint(x:cap.box.midX,y:cap.box.midY)
                    XCTAssertEqual(board.hit(center)?.id,cap.id)
                }
                let l=try XCTUnwrap(letters.first{$0.id=="l"})
                XCTAssertEqual(l.sub,["iang uang","iang",""][style])
                let image=UIGraphicsImageRenderer(bounds:board.bounds).image { _ in board.draw(board.bounds) }
                let attachment=XCTAttachment(image:image)
                attachment.name="Flypy-\(Int(width))-\(style)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }
}
