import XCTest
@testable import CatFacts

final class LocalizationTests: XCTestCase {
    func testAllLanguagesHaveCompleteTranslationsInAppBundle() throws {
        let languages = ["en", "es", "fr", "de", "pt-BR", "ru", "ar", "hi", "zh-Hans", "ja"]
        let expectedKeys = Set(Localization.Key.allCases.map(\.rawValue))

        for language in languages {
            let directory = try XCTUnwrap(Bundle.main.url(forResource: language, withExtension: "lproj"), language)
            let bundle = try XCTUnwrap(Bundle(url: directory), language)
            let file = try XCTUnwrap(bundle.url(forResource: "Localizable", withExtension: "strings"), language)
            let translations = try XCTUnwrap(
                PropertyListSerialization.propertyList(from: Data(contentsOf: file), format: nil) as? [String: String],
                language
            )

            XCTAssertEqual(Set(translations.keys), expectedKeys, language)
            for (key, value) in translations {
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(language): \(key)")
            }
        }
    }

    func testLanguageSelectionIsIndependentBetweenInstances() {
        let english = Localization(languageCode: "en")
        let russian = Localization(languageCode: "ru")
        let arabic = Localization(languageCode: "ar")

        XCTAssertEqual(english[.factsTitle], "Cat Facts")
        XCTAssertEqual(russian[.factsTitle], "Факты о кошках")
        XCTAssertEqual(arabic[.retry], "إعادة المحاولة")
        XCTAssertEqual(english[.retry], "Try Again")
        XCTAssertEqual(russian[.retry], "Повторить")
    }
}
