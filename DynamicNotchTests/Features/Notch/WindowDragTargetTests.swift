import XCTest
@testable import DynamicNotch

final class WindowDragTargetTests: XCTestCase {
    func testTitleBarElementsCanMoveTheWindow() {
        XCTAssertTrue(WindowDragTarget.canMoveWindow(roles: []))
        XCTAssertTrue(WindowDragTarget.canMoveWindow(roles: ["AXWindow"]))
        XCTAssertTrue(WindowDragTarget.canMoveWindow(roles: ["AXStaticText"]))
        XCTAssertTrue(WindowDragTarget.canMoveWindow(roles: ["AXGroup", "AXToolbar"]))
        XCTAssertTrue(WindowDragTarget.canMoveWindow(roles: ["AXTabGroup"]))
    }

    func testAPressOnAControlCannotMoveTheWindow() {
        for role in ["AXButton", "AXRadioButton", "AXPopUpButton", "AXMenuButton", "AXCheckBox", "AXSlider", "AXLink"] {
            XCTAssertFalse(WindowDragTarget.canMoveWindow(roles: [role]), role)
        }
    }

    func testAPressOnAPartOfAControlCannotMoveTheWindow() {
        XCTAssertFalse(WindowDragTarget.canMoveWindow(roles: ["AXStaticText", "AXRadioButton", "AXTabGroup"]))
        XCTAssertFalse(WindowDragTarget.canMoveWindow(roles: ["AXImage", "AXButton", "AXToolbar"]))
        XCTAssertFalse(WindowDragTarget.canMoveWindow(roles: ["AXStaticText", "AXLink", "AXGroup", "AXWebArea"]))
    }

    func testTextFieldsStayExcluded() {
        XCTAssertFalse(WindowDragTarget.canMoveWindow(roles: ["AXTextField"]))
        XCTAssertFalse(WindowDragTarget.canMoveWindow(roles: ["AXTextArea", "AXScrollArea"]))
    }
}
