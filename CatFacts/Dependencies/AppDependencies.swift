import Foundation
import Alamofire

final class AppDependencies: AppDependenciesProtocol {
    let factsService: any FactsServiceProtocol

    init(environment: AppEnvironment = .current) {
        let httpClient = AlamofireHTTPClient(session: Session())
        factsService = FactsService(
            httpClient: httpClient,
            baseURL: environment.baseURL
        )
    }
}
