import AppKit
import XCTest
@testable import DynamicNotch

final class MenuBarIconTests: XCTestCase {
    func testMenuBarIconIsATemplateImageAtMenuBarSize() throws {
        let image = try XCTUnwrap(NSImage(named: "menuBarIcon"))

        XCTAssertTrue(image.isTemplate, "macOS tints only a template image for light and dark menu bars")
        XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
    }
}
