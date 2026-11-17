import XCTest
@testable import DynamicNotch

final class Base64ArtworkDecodeMemoTests: XCTestCase {
    func testRepeatedInputReturnsSameDataAndNewInputDecodesFresh() {
        var memo = Base64ArtworkDecodeMemo()
        let first = Data([0x01, 0x02, 0x03, 0x04]).base64EncodedString()
        let second = Data([0xFF, 0xEE]).base64EncodedString()

        XCTAssertEqual(memo.decode(first), Data([0x01, 0x02, 0x03, 0x04]))
        XCTAssertEqual(memo.decode(first), Data([0x01, 0x02, 0x03, 0x04]))
        XCTAssertEqual(memo.decode(second), Data([0xFF, 0xEE]))
        XCTAssertEqual(memo.decode(first), Data([0x01, 0x02, 0x03, 0x04]))
    }

    func testMalformedInputStaysNilAndDoesNotHideLaterValidInput() {
        var memo = Base64ArtworkDecodeMemo()
        let malformed = "abc"
        let valid = Data([0x10]).base64EncodedString()

        XCTAssertNil(memo.decode(malformed))
        XCTAssertNil(memo.decode(malformed))
        XCTAssertEqual(memo.decode(valid), Data([0x10]))
        XCTAssertNil(memo.decode(malformed))
    }

    func testIgnoresUnknownCharactersLikeDirectDecode() {
        var memo = Base64ArtworkDecodeMemo()
        let input = "AQ\nID"

        XCTAssertEqual(
            memo.decode(input),
            Data(base64Encoded: input, options: .ignoreUnknownCharacters)
        )
    }
}
