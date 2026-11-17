import XCTest
@testable import DynamicNotch

@MainActor
final class ShortTimeFormatterCacheTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_800_000_000)

    func testDefaultProvidersMatchAFreshFormatter() {
        let fresh = DateFormatter()
        fresh.timeStyle = .short

        XCTAssertEqual(ShortTimeFormatterCache().string(from: date), fresh.string(from: date))
    }

    func testRebuildsWhenLocaleOrTimeZoneChanges() {
        var locale = Locale(identifier: "en_US")
        var timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let cache = ShortTimeFormatterCache(currentLocale: { locale }, currentTimeZone: { timeZone })

        XCTAssertEqual(cache.string(from: date), expected(locale: locale, timeZone: timeZone))
        XCTAssertEqual(cache.string(from: date), expected(locale: locale, timeZone: timeZone))

        locale = Locale(identifier: "de_DE")
        XCTAssertEqual(cache.string(from: date), expected(locale: locale, timeZone: timeZone))
        XCTAssertNotEqual(cache.string(from: date), expected(locale: Locale(identifier: "en_US"), timeZone: timeZone))

        timeZone = TimeZone(identifier: "Asia/Tokyo")!
        XCTAssertEqual(cache.string(from: date), expected(locale: locale, timeZone: timeZone))
    }

    private func expected(locale: Locale, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
