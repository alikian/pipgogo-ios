import Foundation

struct Companion: Codable, Equatable, Sendable {
    var nickname: String?
    var relationship: String?
    var ageRange: String?
    var preferences = TravelerPreferences()

    enum CodingKeys: String, CodingKey {
        case nickname, relationship, preferences
        case ageRange = "age_range"
    }

    var displayName: String { nickname?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Unnamed companion" }

    func validated() throws -> Self {
        // These optional fields and preferences share the profile API's limits.
        let validated = try TravelerProfile(nickname: nickname, homeBase: relationship, ageRange: ageRange, preferences: preferences).validated()
        return Companion(nickname: validated.nickname, relationship: validated.homeBase, ageRange: validated.ageRange, preferences: validated.preferences)
    }

    var summary: [(String, String)] {
        let profile = TravelerProfile(nickname: nickname, ageRange: ageRange, preferences: preferences).summary
        return [profile[0], ("Relationship", relationship ?? "Not set"), profile[2]] + Array(profile.dropFirst(4))
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

protocol CompanionServing: Sendable {
    func list() async throws -> [APIRecord<Companion>]
    // Deletes return an empty data object, so decode the envelope before its body.
    func mutate(_ request: APIRequest<APIRecord<JSONValue>>) async throws -> APIRecord<JSONValue>
}

struct CompanionService: CompanionServing {
    let client: APIClient
    let authentication: any AccessTokenProviding

    func list() async throws -> [APIRecord<Companion>] {
        let response: APIRecordList<Companion> = try await client.send(.get(.companions), using: authentication)
        return response.items.filter { !$0.deleted }
    }

    func mutate(_ request: APIRequest<APIRecord<JSONValue>>) async throws -> APIRecord<JSONValue> {
        try await client.send(request, using: authentication)
    }
}

extension APIRecord where Body == JSONValue {
    func companion() throws -> APIRecord<Companion> {
        guard !deleted, kind == "companion" else { throw APIClientError.invalidResponse }
        return APIRecord<Companion>(id: id, kind: kind, version: version, revision: revision, updatedAt: updatedAt, deleted: false, data: try data.decoded(as: Companion.self))
    }
}
