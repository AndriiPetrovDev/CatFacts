import Foundation

struct CatFactDTO: Decodable {
    let id: String
    let text: String
    let createdAt: Date
    let status: Status

    private enum CodingKeys: String, CodingKey {
        case id = "_id"
        case text
        case createdAt
        case status
    }

    struct Status: Decodable {
        let verified: Bool?
    }

    func toDomain() -> CatFact {
        CatFact(id: id, text: text, createdAt: createdAt, isVerified: status.verified == true)
    }
}
