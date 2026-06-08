import XCTest
@testable import XMarkup

final class MarkupAttachmentTests: XCTestCase {

    func testImageAttachment() {
        let attachment = MarkupAttachment(
            content: .image(src: "photo.jpg"),
            suggestedSize: CGSize(width: 200, height: 150),
            alignment: .default
        )
        if case let .image(src) = attachment.content {
            XCTAssertEqual(src, "photo.jpg")
        } else {
            XCTFail("Expected .image(src:)")
        }
        XCTAssertEqual(attachment.suggestedSize, CGSize(width: 200, height: 150))
    }

    func testVideoAttachment() {
        let attachment = MarkupAttachment(
            content: .video(src: "movie.mp4"),
            suggestedSize: CGSize(width: 300, height: 200),
            alignment: .center
        )
        if case let .video(src) = attachment.content {
            XCTAssertEqual(src, "movie.mp4")
        } else {
            XCTFail("Expected .video(src:)")
        }
        XCTAssertEqual(attachment.alignment, .center)
    }

    func testAudioAttachment() {
        let attachment = MarkupAttachment(
            content: .audio(src: "song.mp3"),
            suggestedSize: CGSize(width: 200, height: 44),
            alignment: .default
        )
        if case let .audio(src) = attachment.content {
            XCTAssertEqual(src, "song.mp3")
        } else {
            XCTFail("Expected .audio(src:)")
        }
    }

    func testCustomAttachment() {
        let attachment = MarkupAttachment(
            content: .custom(type: "map", metadata: ["lat": "39.9", "lng": "116.4"]),
            suggestedSize: CGSize(width: 200, height: 200),
            alignment: .center
        )
        if case let .custom(type, metadata) = attachment.content {
            XCTAssertEqual(type, "map")
            XCTAssertEqual(metadata["lat"], "39.9")
        } else {
            XCTFail("Expected .custom(type:metadata:)")
        }
    }

    func testAttachmentEquality() {
        let a = MarkupAttachment(
            content: .image(src: "a.jpg"),
            suggestedSize: CGSize(width: 100, height: 100),
            alignment: .default
        )
        let b = MarkupAttachment(
            content: .image(src: "a.jpg"),
            suggestedSize: CGSize(width: 100, height: 100),
            alignment: .default
        )
        XCTAssertEqual(a, b)
    }

    func testAttachmentInequality() {
        let a = MarkupAttachment(
            content: .image(src: "a.jpg"),
            suggestedSize: CGSize(width: 100, height: 100),
            alignment: .default
        )
        let b = MarkupAttachment(
            content: .video(src: "a.mp4"),
            suggestedSize: CGSize(width: 100, height: 100),
            alignment: .default
        )
        XCTAssertNotEqual(a, b)
    }

    func testAlignmentDefault() {
        let attachment = MarkupAttachment(
            content: .image(src: "x.jpg"),
            suggestedSize: .zero,
            alignment: .default
        )
        XCTAssertEqual(attachment.alignment, .default)
    }
}
