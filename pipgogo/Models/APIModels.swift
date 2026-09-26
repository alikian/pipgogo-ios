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

struct APIRecord<Body: Codable & Sendable>: Codable, Sendable, Identifiable {
    let id: String
    let kind: String
    let version: Int
    let revision: Int
    let updatedAt: Date
    let deleted: Bool
    let data: Body

    enum CodingKeys: String, CodingKey {
        case id, kind, version, revision, deleted, data
        case updatedAt = "updated_at"
    }
}
extension APIRecord: Equatable where Body: Equatable {}

struct APIRecordList<Body: Codable & Sendable>: Codable, Sendable {
    let items: [APIRecord<Body>]
}

struct APISyncResponse: Codable, Sendable {
    let cursor: Int
    let changes: [APIRecord<JSONValue>]
}

/// Preserve structured errors and heterogeneous records, including nulls and integer versions.
/// Feature-specific editable models will be added with each screen; do not send record envelopes as PUT bodies.
enum JSONValue: Codable, Equatable, Sendable {
    case null, bool(Bool), integer(Int64), number(Double), string(String)
    case array([JSONValue]), object([String: JSONValue])

    init(from decoder: any Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let x = try? value.decode(Bool.self) { self = .bool(x) }
        else if let x = try? value.decode(Int64.self) { self = .integer(x) }
        else if let x = try? value.decode(Double.self) { self = .number(x) }
        else if let x = try? value.decode(String.self) { self = .string(x) }
        else if let x = try? value.decode([JSONValue].self) { self = .array(x) }
        else { self = .object(try value.decode([String: JSONValue].self)) }
    }

    func encode(to encoder: any Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .null: try value.encodeNil()
        case .bool(let x): try value.encode(x)
        case .integer(let x): try value.encode(x)
        case .number(let x): try value.encode(x)
        case .string(let x): try value.encode(x)
        case .array(let x): try value.encode(x)
        case .object(let x): try value.encode(x)
        }
    }

    subscript(key: String) -> JSONValue? {
        guard case .object(let value) = self else { return nil }
        return value[key]
    }

    func decoded<Value: Decodable>(as type: Value.Type) throws -> Value {
        try APIJSON.decoder().decode(type, from: APIJSON.encoder().encode(self))
    }
}

struct APIErrorEnvelope: Decodable, Sendable {
    let error: APIErrorBody
}

struct APIErrorBody: Decodable, Equatable, Sendable {
    let code: String
    let message: String
    let details: JSONValue?
    let requestID: String?

    init(code: String, message: String, details: JSONValue? = nil, requestID: String? = nil) {
        self.code = code
        self.message = message
        self.details = details
        self.requestID = requestID
    }

    enum CodingKeys: String, CodingKey {
        case code, message, details
        case requestID = "request_id"
    }

    /// Only version conflicts have a current record. Other 409s retain their code/details.
    var currentRecord: APIRecord<JSONValue>? {
        guard let current = details?["current"] else { return nil }
        return try? current.decoded(as: APIRecord<JSONValue>.self)
    }
}

enum APIClientError: LocalizedError, Equatable {
    case invalidRequest(String)
    case invalidResponse
    case unauthorized
    case rejected(status: Int, error: APIErrorBody, requestID: String?)
    case conflict(APIErrorBody, requestID: String?)
    case connection
    case decoding

    var errorDescription: String? {
        switch self {
        case .invalidRequest(let message): message
        case .invalidResponse: "The server returned an invalid response."
        case .unauthorized: "Your session is no longer valid. Please sign in again."
        case .rejected(_, let error, _), .conflict(let error, _): error.message
        case .connection: "Couldn’t connect to the PipGoGo backend. Your request may not have finished; retry the same operation when connected."
        case .decoding: "The server returned data this app could not read."
        }
    }
}

enum APIJSON {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected an ISO 8601 date.")
        }
        return decoder
    }
}
