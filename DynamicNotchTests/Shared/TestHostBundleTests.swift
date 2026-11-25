import XCTest
@testable import DynamicNotch

final class TestHostBundleTests: XCTestCase {
    /// The tests run inside a Debug build of the app. That build must not have the bundle ID of the installed app,
    /// or macOS applies the privacy permissions and the settings of the installed app to the test host.
    func testTestHostDoesNotUseTheBundleIDOfTheInstalledApp() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "com.kevster.DynamicNotch.debug")
    }
}
