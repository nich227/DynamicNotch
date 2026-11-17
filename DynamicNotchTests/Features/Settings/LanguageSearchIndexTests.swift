import XCTest
@testable import DynamicNotch

@MainActor
final class LanguageSearchIndexTests: XCTestCase {
    func testLocalizedTitleIsReusedUntilAppLanguageChanges() {
        var appLanguage = DynamicNotchLanguage.english

        var lookups = 0
        let index = LanguageSearchIndex(localizedTitle: { language, appLanguage in
            lookups += 1
            return appLanguage == .english ? "Title-\(language.rawValue)" : "Titel-\(language.rawValue)"
        })

        XCTAssertTrue(index.matches(.german, query: "title-de", appLanguage: appLanguage))
        XCTAssertTrue(index.matches(.german, query: "title-de", appLanguage: appLanguage))
        XCTAssertEqual(lookups, 1)

        appLanguage = .german
        XCTAssertFalse(index.matches(.german, query: "title-de", appLanguage: appLanguage))
        XCTAssertTrue(index.matches(.german, query: "titel-de", appLanguage: appLanguage))
        XCTAssertEqual(lookups, 2)
    }

    func testMatchesSameFieldsAsDirectComparison() {
        let index = LanguageSearchIndex()
        let queries = ["en", "deutsch", "日本", "zh-hans", "xyz", "fr", "español"]

        for language in DynamicNotchLanguage.allCases where language != .system {
            for appLanguage in [DynamicNotchLanguage.english, .russian, .system] {
                for query in queries {
                    let expected = language.fallbackDisplayName.lowercased().contains(query) ||
                        language.nativeDisplayName.lowercased().contains(query) ||
                        language.rawValue.lowercased().contains(query) ||
                        L10n.string(language.titleKeyString, language: appLanguage).lowercased().contains(query)
                    XCTAssertEqual(
                        index.matches(language, query: query, appLanguage: appLanguage),
                        expected,
                        "\(language) \(appLanguage) \(query)"
                    )
                }
            }
        }
    }
}
