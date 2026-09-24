import XCTest

final class LocalizationTests: XCTestCase {
    func testAllLanguagesHaveCompleteTranslationsInAppBundle() throws {
        let languages = ["en", "es", "fr", "de", "pt-BR", "ar", "hi", "zh-Hans", "ja"]
        let expectedKeys = try Set(translations(for: "en").keys)
        XCTAssertFalse(expectedKeys.isEmpty)

        for language in languages {
            let translations = try translations(for: language)

            XCTAssertEqual(Set(translations.keys), expectedKeys, language)
            for (key, value) in translations {
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(language): \(key)")
            }
        }
    }

    private func translations(for language: String) throws -> [String: String] {
        let directory = try XCTUnwrap(Bundle.main.url(forResource: language, withExtension: "lproj"), language)
        let bundle = try XCTUnwrap(Bundle(url: directory), language)
        let file = try XCTUnwrap(bundle.url(forResource: "Localizable", withExtension: "strings"), language)
        return try XCTUnwrap(
            PropertyListSerialization.propertyList(from: Data(contentsOf: file), format: nil) as? [String: String],
            language
        )
    }
}
