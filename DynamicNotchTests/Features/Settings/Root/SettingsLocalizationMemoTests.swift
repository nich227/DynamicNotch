import XCTest
@testable import DynamicNotch

@MainActor
final class SettingsLocalizationMemoTests: XCTestCase {
    func testStringIsReusedUntilAppLanguageChanges() {
        let suiteName = "SettingsLocalizationMemoTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = ApplicationSettingsStore(defaults: defaults)
        settings.appLanguage = .english

        var lookups = 0
        let memo = SettingsLocalizationMemo(lookup: { key, fallback, locale in
            lookups += 1
            return locale.dn(key, fallback: fallback)
        })

        let first = memo.string("settings.search.prompt", fallback: nil, locale: settings.appLanguage.locale)
        let second = memo.string("settings.search.prompt", fallback: nil, locale: settings.appLanguage.locale)
        XCTAssertEqual(first, second)
        XCTAssertEqual(lookups, 1)

        let third = memo.string("settings.search.prompt", fallback: nil, locale: DynamicNotchLanguage.german.locale)
        XCTAssertEqual(lookups, 2)
        XCTAssertEqual(third, DynamicNotchLanguage.german.locale.dn("settings.search.prompt"))
    }

    func testFallbackIsPartOfTheStringKey() {
        var lookups = 0
        let memo = SettingsLocalizationMemo(lookup: { key, fallback, _ in
            lookups += 1
            return "\(key)|\(fallback ?? "nil")"
        })
        let locale = Locale(identifier: "en")

        XCTAssertEqual(memo.string("k", fallback: "A", locale: locale), "k|A")
        XCTAssertEqual(memo.string("k", fallback: "B", locale: locale), "k|B")
        XCTAssertEqual(memo.string("k", fallback: nil, locale: locale), "k|nil")
        XCTAssertEqual(lookups, 3)
    }

    func testPreferredLocalizationChangeClearsTheStrings() {
        var lookups = 0
        var preferred: String? = "en"
        let memo = SettingsLocalizationMemo(
            lookup: { key, _, _ in
                lookups += 1
                return key
            },
            preferredLocalization: { preferred }
        )
        let locale = Locale(identifier: "en")

        _ = memo.string("k", fallback: nil, locale: locale)
        _ = memo.string("k", fallback: nil, locale: locale)
        XCTAssertEqual(lookups, 1)

        preferred = "fr"
        _ = memo.string("k", fallback: nil, locale: locale)
        XCTAssertEqual(lookups, 2)
    }
}
