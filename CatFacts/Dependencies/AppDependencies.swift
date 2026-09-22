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
}
