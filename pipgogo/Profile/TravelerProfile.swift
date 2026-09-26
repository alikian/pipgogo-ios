import Foundation

struct TravelerPreferences: Codable, Equatable, Sendable {
    var languages: [String] = []
    var interests: [String] = []
    var dietaryNeeds: [String] = []
    var accessibilityNeeds: [String] = []
    var pace: String?
    var budgetComfort: String?
    var transportation: [String] = []

    enum CodingKeys: String, CodingKey {
        case languages, interests, pace, transportation
        case dietaryNeeds = "dietary_needs"
        case accessibilityNeeds = "accessibility_needs"
        case budgetComfort = "budget_comfort"
    }
}

struct TravelerProfile: Codable, Equatable, Sendable {
    var nickname: String?
    var homeBase: String?
    var ageRange: String?
    var usualParty: String?
    var preferences = TravelerPreferences()

    enum CodingKeys: String, CodingKey {
        case nickname, preferences
        case homeBase = "home_base"
        case ageRange = "age_range"
        case usualParty = "usual_party"
    }

    func validated() throws -> Self {
        var result = self
        func optional(_ value: String?) throws -> String? {
            guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
            guard text.unicodeScalars.count <= 300 else { throw ProfileValidationError.message("Keep each entry to 300 characters or fewer.") }
            return text
        }
        func list(_ values: [String]) throws -> [String] {
            let result = try values.compactMap { try optional($0) }
            guard result.count <= 30 else { throw ProfileValidationError.message("Use no more than 30 entries in each preference list.") }
            return result
        }
        result.nickname = try optional(nickname)
        result.homeBase = try optional(homeBase)
        result.ageRange = try optional(ageRange)
        result.preferences.languages = try list(preferences.languages)
        result.preferences.interests = try list(preferences.interests)
        result.preferences.dietaryNeeds = try list(preferences.dietaryNeeds)
        result.preferences.accessibilityNeeds = try list(preferences.accessibilityNeeds)
        result.preferences.transportation = try list(preferences.transportation)
        return result
    }

    var summary: [(String, String)] {
        func text(_ value: String?) -> String { value.flatMap { $0.isEmpty ? nil : $0 } ?? "Not set" }
        func list(_ values: [String]) -> String { values.isEmpty ? "Not set" : values.joined(separator: ", ") }
        return [("Name", text(nickname)), ("Home base", text(homeBase)), ("Age range", text(ageRange)),
                ("Travel party", text(usualParty)), ("Languages", list(preferences.languages)),
                ("Interests", list(preferences.interests)), ("Dietary needs", list(preferences.dietaryNeeds)),
                ("Accessibility needs", list(preferences.accessibilityNeeds)), ("Pace", text(preferences.pace)),
                ("Budget comfort", text(preferences.budgetComfort)), ("Transportation", list(preferences.transportation))]
    }
}

enum ProfileValidationError: LocalizedError {
    case message(String)
    var errorDescription: String? { switch self { case .message(let value): value } }
}

protocol ProfileServing: Sendable {
    func load() async throws -> APIRecord<TravelerProfile>?
    func save(_ request: APIRequest<APIRecord<TravelerProfile>>) async throws -> APIRecord<TravelerProfile>
}

struct ProfileService: ProfileServing {
    let client: APIClient
    let authentication: any AccessTokenProviding
    func load() async throws -> APIRecord<TravelerProfile>? {
        do { return try await client.send(.get(.profile), using: authentication) }
        catch APIClientError.rejected(let status, let error, _) where status == 404 && error.code == "not_found" { return nil }
    }
    func save(_ request: APIRequest<APIRecord<TravelerProfile>>) async throws -> APIRecord<TravelerProfile> {
        try await client.send(request, using: authentication)
    }
}
