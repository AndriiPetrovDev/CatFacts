import Foundation
import Alamofire

final class AppDependencies {
    let factsService: any FactsServiceProtocol

    init(factsService: any FactsServiceProtocol) {
        self.factsService = factsService
    }

    static func live(environment: AppEnvironment = .current) -> AppDependencies {
        let httpClient = AlamofireHTTPClient(session: Session())
        let factsService = FactsService(
            httpClient: httpClient,
            baseURL: environment.baseURL
        )

        return AppDependencies(factsService: factsService)
    }

    #if DEBUG
        static func mockFailure(error: HTTPClientError = .httpStatus(503), environment: AppEnvironment = .current) -> AppDependencies {
            let factsService = FactsService(
                httpClient: MockHTTPClient(error: error),
                baseURL: environment.baseURL
            )

            return AppDependencies(factsService: factsService)
        }
    #endif
}
