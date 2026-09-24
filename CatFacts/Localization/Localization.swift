import Foundation

struct Localization: Sendable {
    enum Key: String, CaseIterable {
        case factsTitle = "facts.title"
        case factTitle = "fact.title"
        case detailsTitle = "details.title"
        case searchPlaceholder = "search.placeholder"
        case new = "status.new"
        case verified = "status.verified"
        case statusSeparator = "status.separator"
        case retry = "action.retry"
        case retryHint = "accessibility.retry"
        case openDetailsHint = "accessibility.openDetails"
        case loading = "facts.loading"
        case empty = "facts.empty"
        case noMatches = "search.empty"
        case offlineError = "error.offline"
        case timeoutError = "error.timeout"
        case serverError = "error.server"
        case genericError = "error.generic"
    }

    private let bundle: Bundle

    init(languageCode: String? = nil, bundle: Bundle = .main) {
        if let languageCode,
           let url = bundle.url(forResource: languageCode, withExtension: "lproj"),
           let localizedBundle = Bundle(url: url) {
            self.bundle = localizedBundle
        } else {
            self.bundle = bundle
        }
    }

    subscript(key: Key) -> String {
        bundle.localizedString(forKey: key.rawValue, value: nil, table: "Localizable")
    }
}
