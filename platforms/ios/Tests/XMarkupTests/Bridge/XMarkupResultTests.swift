import CXMarkup
import XCTest
@testable import XMarkup

final class XMarkupResultTests: XCTestCase {
    func testTagMapping() {
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_BOLD), .bold)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_ITALIC), .italic)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_LINK), .link)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_HEADING_1), .heading1)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_LINE_BREAK), .lineBreak)
    }

    func testUnknownTag() {
        if case let .unknown(val) = XMarkupTag(cValue: XMTagType(rawValue: 999)) {
            XCTAssertEqual(val, 999)
        } else {
            XCTFail("Expected unknown tag")
        }
    }

    func testStyleMapping() {
        XCTAssertEqual(XMarkupStyle(cValue: XM_STYLE_FOREGROUND_COLOR), .foregroundColor)
        XCTAssertEqual(XMarkupStyle(cValue: XM_STYLE_FONT_SIZE), .fontSize)
    }

    func testErrorMapping() {
        XCTAssertEqual(XMarkupError(cError: XM_ERR_NULL_PARSER), .nullParser)
        XCTAssertEqual(XMarkupError(cError: XM_ERR_NULL_INPUT), .nullInput)
        XCTAssertEqual(XMarkupError(cError: XM_OK), .unknown(code: 0))
    }

    // MARK: - Tag 枚举完整性

    func testAllTextStyleTagMapping() {
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_BOLD), .bold)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_ITALIC), .italic)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_UNDERLINE), .underline)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_STRIKETHROUGH), .strikethrough)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_SUBSCRIPT), .subscriptText)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_SUPERSCRIPT), .superscript)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_MARK), .mark)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_CODE), .code)
    }

    func testAllParagraphTagMapping() {
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_PARAGRAPH), .paragraph)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_HEADING_1), .heading1)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_HEADING_2), .heading2)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_HEADING_3), .heading3)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_HEADING_4), .heading4)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_HEADING_5), .heading5)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_HEADING_6), .heading6)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_BLOCKQUOTE), .blockquote)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_PREFORMATTED), .preformatted)
    }

    func testAllMediaTagMapping() {
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_LINK), .link)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_IMAGE), .image)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_VIDEO), .video)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_VIDEO_SOURCE), .videoSource)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_AUDIO), .audio)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_AUDIO_SOURCE), .audioSource)
    }

    func testAllTableTagMapping() {
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_TABLE), .table)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_TABLE_ROW), .tableRow)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_TABLE_CELL), .tableCell)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_TABLE_HEADER), .tableHeader)
    }

    func testAllOtherTagMapping() {
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_HORIZONTAL_RULE), .horizontalRule)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_LINE_BREAK), .lineBreak)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_DIVISION), .division)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_SPAN), .span)
    }

    func testSemanticBlockTagMapping() {
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_ARTICLE), .article)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_SECTION), .section)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_HEADER), .header)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_FOOTER), .footer)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_NAV), .nav)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_ASIDE), .aside)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_FIGURE), .figure)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_FIGCAPTION), .figcaption)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_MAIN), .main)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_ADDRESS), .address)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_DL), .definitionList)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_DT), .definitionTerm)
        XCTAssertEqual(XMarkupTag(cValue: XM_TAG_DD), .definitionDescription)
    }

    // MARK: - Style 枚举完整性

    func testAllStyleMapping() {
        XCTAssertEqual(XMarkupStyle(cValue: XM_STYLE_FOREGROUND_COLOR), .foregroundColor)
        XCTAssertEqual(XMarkupStyle(cValue: XM_STYLE_BACKGROUND_COLOR), .backgroundColor)
        XCTAssertEqual(XMarkupStyle(cValue: XM_STYLE_FONT_SIZE), .fontSize)
        XCTAssertEqual(XMarkupStyle(cValue: XM_STYLE_FONT_WEIGHT), .fontWeight)
        XCTAssertEqual(XMarkupStyle(cValue: XM_STYLE_FONT_STYLE), .fontStyle)
        XCTAssertEqual(XMarkupStyle(cValue: XM_STYLE_TEXT_DECORATION), .textDecoration)
        XCTAssertEqual(XMarkupStyle(cValue: XM_STYLE_LINE_HEIGHT), .lineHeight)
        XCTAssertEqual(XMarkupStyle(cValue: XM_STYLE_TEXT_ALIGN), .textAlign)
        XCTAssertEqual(XMarkupStyle(cValue: XM_STYLE_LETTER_SPACING), .letterSpacing)
        XCTAssertEqual(XMarkupStyle(cValue: XM_STYLE_MEDIA_TYPE), .mediaType)
        XCTAssertEqual(XMarkupStyle(cValue: XM_STYLE_MEDIA_QUERY), .mediaQuery)
    }

    func testMediaStyleMapping() {
        XCTAssertEqual(XMarkupStyle(cValue: XM_STYLE_MEDIA_TYPE), .mediaType)
        XCTAssertEqual(XMarkupStyle(cValue: XM_STYLE_MEDIA_QUERY), .mediaQuery)
        XCTAssertNotEqual(XMarkupStyle(cValue: XM_STYLE_MEDIA_TYPE), .unknown(styleValue: 10))
    }

    // MARK: - Error 枚举完整性

    func testAllErrorCodeMapping() {
        XCTAssertEqual(XMarkupError(cError: XM_ERR_NULL_PARSER), .nullParser)
        XCTAssertEqual(XMarkupError(cError: XM_ERR_NULL_INPUT), .nullInput)
        XCTAssertEqual(XMarkupError(cError: XM_ERR_NESTING_OVERFLOW), .nestingOverflow)
        XCTAssertEqual(XMarkupError(cError: XM_ERR_ALLOC_FAILED), .allocationFailed)
    }
}
