//
//  FactsApi.swift
//  CatFacts
//
//  Created by Kerem Gunduz on 30/03/2021.
//

import Foundation
import Alamofire

class FactsApi {
    
    
    func getFacts(completion: @escaping ([CatFact]?, Error?) -> Void) {

        AF.request("https://api.npoint.io/18962a8a5d00e62a8d2a")
            .validate(statusCode: 200..<300)
            .validate(contentType: ["application/json"])
            .responseDecodable(of: [CatFact].self, decoder: CustomDecoder()) { response in
                switch response.result {
                case .success:
                    let facts = try! response.result.get()
                    completion(facts, nil)
                case let .failure(error):
                    completion(nil, error)
                }
        }
    }
}

class CustomDecoder: JSONDecoder {
    static let iso8601Full: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss Z"
        return formatter
      }()

    override init() {
        super.init()
        dateDecodingStrategy = .formatted(CustomDecoder.iso8601Full)
    }
}
