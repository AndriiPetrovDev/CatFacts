#if DEBUG
    import SwiftUI
    import UIKit

    @available(iOS 17.0, *)
    @MainActor
    struct LocalizedPreview: View {
        @State private var languageCode = "en"
        let makeController: @MainActor (Localization) -> UIViewController

        private let languages = [
            (code: "en", name: "English"),
            (code: "es", name: "Español"),
            (code: "fr", name: "Français"),
            (code: "de", name: "Deutsch"),
            (code: "pt-BR", name: "Português (Brasil)"),
            (code: "ru", name: "Русский"),
            (code: "ar", name: "العربية"),
            (code: "hi", name: "हिन्दी"),
            (code: "zh-Hans", name: "简体中文"),
            (code: "ja", name: "日本語")
        ]

        var body: some View {
            VStack(spacing: 0) {
                Picker("Language", selection: $languageCode) {
                    ForEach(languages, id: \.code) { language in
                        Text(language.name).tag(language.code)
                    }
                }
                .pickerStyle(.menu)

                ControllerPreview(
                    localization: Localization(languageCode: languageCode),
                    isRightToLeft: languageCode == "ar",
                    makeController: makeController
                )
                .id(languageCode)
                .environment(\.locale, Locale(identifier: languageCode))
                .environment(\.layoutDirection, languageCode == "ar" ? .rightToLeft : .leftToRight)
            }
        }
    }

    @available(iOS 17.0, *)
    @MainActor
    private struct ControllerPreview: UIViewControllerRepresentable {
        let localization: Localization
        let isRightToLeft: Bool
        let makeController: @MainActor (Localization) -> UIViewController

        func makeUIViewController(context: Context) -> UIViewController {
            let controller = makeController(localization)
            let direction: UISemanticContentAttribute = isRightToLeft ? .forceRightToLeft : .forceLeftToRight
            controller.view.semanticContentAttribute = direction
            if let navigationController = controller as? UINavigationController {
                navigationController.navigationBar.semanticContentAttribute = direction
                navigationController.toolbar.semanticContentAttribute = direction
                navigationController.topViewController?.view.semanticContentAttribute = direction
            }
            return controller
        }

        func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    }
#endif
