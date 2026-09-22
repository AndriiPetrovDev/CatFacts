import Foundation

struct AppEnvironment: Sendable {
    let baseURL: String

    static let debug = AppEnvironment(baseURL: "https://api.npoint.io/")
    static let production = AppEnvironment(baseURL: "https://api.npoint.io/")

    static var current: AppEnvironment {
        #if DEBUG
            return .debug
        #else
            return .production
        #endif
    }
}
