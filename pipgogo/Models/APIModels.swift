import Foundation

struct AccountRecord: Decodable, Equatable, Sendable {
    let id: String
    let kind: String
    let version: Int
    let revision: Int
    let updatedAt: Date
    let deleted: Bool

    enum CodingKeys: String, CodingKey {
        case id, kind, version, revision, deleted
        case updatedAt = "updated_at"
    }
}

struct APIErrorEnvelope: Decodable, Sendable {
    let error: APIErrorBody
}

struct APIErrorBody: Decodable, Sendable {
    let code: String
    let message: String
}

enum APIClientError: LocalizedError, Equatable {
    case invalidResponse
    case unauthorized
    case server(status: Int, message: String)
    case connection
    case decoding

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The server returned an invalid response."
        case .unauthorized: "Your session is no longer valid. Please sign in again."
        case .server(_, let message): message
        case .connection: "Couldn’t connect to the pipgogo backend. Check that the server is running and the configured address is reachable."
        case .decoding: "The server returned data this app could not read."
        }
    }
}
