import XCTest
@testable import DynamicNotch

final class NewlineDelimitedBufferTests: XCTestCase {
    func testSplitsLinesInOrderAndSkipsEmptyLines() {
        var buffer = NewlineDelimitedBuffer()
        let lines = buffer.append(Data("a\n\nb\nc\n".utf8))
        XCTAssertEqual(lines.map { String(decoding: $0, as: UTF8.self) }, ["a", "b", "c"])
    }

    func testKeepsPartialLineAcrossChunks() {
        var buffer = NewlineDelimitedBuffer()
        XCTAssertEqual(buffer.append(Data("{\"x\":".utf8)), [])
        XCTAssertEqual(buffer.append(Data("1}".utf8)), [])
        let lines = buffer.append(Data("\n{\"y\"".utf8))
        XCTAssertEqual(lines.map { String(decoding: $0, as: UTF8.self) }, ["{\"x\":1}"])
        let rest = buffer.append(Data(":2}\n".utf8))
        XCTAssertEqual(rest.map { String(decoding: $0, as: UTF8.self) }, ["{\"y\":2}"])
    }

    func testKeepsMultiByteCharacterSplitAcrossChunks() {
        var buffer = NewlineDelimitedBuffer()
        let bytes = Array("é\n".utf8)
        XCTAssertEqual(buffer.append(Data(bytes[0..<1])), [])
        let lines = buffer.append(Data(bytes[1...]))
        XCTAssertEqual(lines.map { String(decoding: $0, as: UTF8.self) }, ["é"])
    }

    func testRepeatedIdenticalLinesAreAllReturned() {
        var buffer = NewlineDelimitedBuffer()
        let lines = buffer.append(Data("same\nsame\n".utf8))
        XCTAssertEqual(lines.count, 2)
    }
}
