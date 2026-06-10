import XCTest
@testable import XMarkupUI
@testable import XMarkup

final class XMarkupViewConfigTests: XCTestCase {

    func testDefaultValues() {
        let config = XMarkupViewConfig()
        XCTAssertEqual(config.hrMinWidth, 100)
        XCTAssertEqual(config.blockquoteBorderWidth, 3)
        XCTAssertTrue(config.enableMediaAutoLoad)
    }

    func testSharedInstance() {
        let instance = XMarkupUI.shared
        XCTAssertEqual(instance.config.hrMinWidth, 100)
    }

    func testConfigModifiable() {
        var config = XMarkupViewConfig()
        config.hrMinWidth = 200
        XCTAssertEqual(config.hrMinWidth, 200)
    }

    // MARK: - HorizontalRuleUpdater

    func testHorizontalRuleUpdater() {
        let attachment = NSTextAttachment()
        attachment.bounds = CGRect(x: 0, y: 0, width: 300, height: 1)
        let attrString = NSMutableAttributedString(attachment: attachment)
        attrString.addAttribute(
            NSAttributedString.Key(XMarkupBlockKindKey.name),
            value: "horizontalRule",
            range: NSRange(location: 0, length: attrString.length)
        )
        let storage = NSTextStorage(attributedString: attrString)

        HorizontalRuleUpdater.update(in: storage, containerWidth: 200, minWidth: 50)
        let updatedAttachment = storage.attribute(.attachment, at: 0, effectiveRange: nil) as? NSTextAttachment
        XCTAssertEqual(updatedAttachment?.bounds.width, 200)
    }
}
