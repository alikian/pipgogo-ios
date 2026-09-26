import Foundation

struct TripAccommodation: Codable, Equatable, Sendable {
    var name: String?
    var address: String?
    var checkIn: String?
    var instructions: String?
    var reservationReference: String?
    enum CodingKeys: String, CodingKey {
        case name, address, instructions
        case checkIn = "check_in"
        case reservationReference = "reservation_reference"
    }
}

struct TripFlight: Codable, Equatable, Sendable {
    var number: String?
    var airport: String?
    var scheduledAt: String?
    enum CodingKeys: String, CodingKey {
        case number, airport
        case scheduledAt = "scheduled_at"
    }
}

/// Retain every current backend field, even before its editor is available.
struct Trip: Codable, Equatable, Sendable {
    var destinations: [String] = []
    var startDate: String?
    var endDate: String?
    var accommodation: TripAccommodation?
    var arrival: TripFlight?
    var departure: TripFlight?
    var companionIDs: [String] = []
    var preferences = TravelerPreferences()
    var budgetMinor: Int?
    var currency: String?
    var transportationPlan: String?
    var itinerary: [String] = []
    var constraints: [String] = []

    enum CodingKeys: String, CodingKey {
        case destinations, accommodation, arrival, departure, preferences, currency, itinerary, constraints
        case startDate = "start_date"
        case endDate = "end_date"
        case companionIDs = "companion_ids"
        case budgetMinor = "budget_minor"
        case transportationPlan = "transportation_plan"
    }

    var title: String { destinations.joined(separator: " → ") }
    var dateSummary: String {
        switch (startDate, endDate) {
        case (let start?, let end?): "\(start) – \(end)"
        case (let start?, nil): "From \(start)"
        case (nil, let end?): "Until \(end)"
        default: "Dates not set"
        }
    }

    func validated() throws -> Self {
        var value = self
        func text(_ input: String?, limit: Int = 300) throws -> String? {
            guard let trimmed = input?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
            guard trimmed.unicodeScalars.count <= limit else { throw TripValidationError.message("Keep each entry to \(limit) characters or fewer.") }
            return trimmed
        }
        value.destinations = try destinations.compactMap { try text($0) }
        guard (1...10).contains(value.destinations.count) else { throw TripValidationError.message("Enter between 1 and 10 destinations, one per line.") }
        for day in [startDate, endDate].compactMap({ $0 }) {
            guard TripDates.date(day) != nil else { throw TripValidationError.message("Choose a valid trip date.") }
        }
        if let startDate, let endDate, endDate < startDate { throw TripValidationError.message("The end date cannot be before the start date.") }
        guard companionIDs.count <= 20, Set(companionIDs).count == companionIDs.count,
              companionIDs.allSatisfy({ UUID(uuidString: $0) != nil }) else {
            throw TripValidationError.message("Choose up to 20 different companions.")
        }
        if var lodging = accommodation {
            lodging.name = try text(lodging.name)
            lodging.address = try text(lodging.address)
            lodging.instructions = try text(lodging.instructions, limit: 2000)
            lodging.reservationReference = try text(lodging.reservationReference)
            value.accommodation = lodging == TripAccommodation() ? nil : lodging
        }
        value.transportationPlan = try text(transportationPlan, limit: 2000)
        value.itinerary = try itinerary.compactMap { try text($0) }
        value.constraints = try constraints.compactMap { try text($0) }
        guard value.itinerary.count <= 50, value.constraints.count <= 30 else {
            throw TripValidationError.message("Use up to 50 itinerary entries and 30 constraints.")
        }
        value.preferences = try TravelerProfile(preferences: preferences).validated().preferences
        if let budgetMinor {
            guard (0...1_000_000_000_000).contains(budgetMinor), currency != nil else {
                throw TripValidationError.message("A budget needs a currency and a valid nonnegative amount.")
            }
        }
        if let currency, currency.range(of: "^[A-Z]{3}$", options: .regularExpression) == nil {
            throw TripValidationError.message("Use a three-letter currency code.")
        }
        return value
    }
}

enum TripValidationError: LocalizedError {
    case message(String)
    var errorDescription: String? { switch self { case .message(let value): value } }
}

/// A calendar day travels over the API as YYYY-MM-DD, never as a UTC timestamp.
enum TripDates {
    private static func formatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }
    static func string(_ date: Date) -> String { formatter().string(from: date) }
    static func date(_ string: String) -> Date? {
        let formatter = formatter()
        guard string.count == 10, let date = formatter.date(from: string), formatter.string(from: date) == string else { return nil }
        return date
    }
}

protocol TripServing: Sendable {
    func list() async throws -> [APIRecord<Trip>]
    func load(_ id: UUID) async throws -> APIRecord<Trip>
    func save(_ request: APIRequest<APIRecord<Trip>>) async throws -> APIRecord<Trip>
    func delete(_ request: APIRequest<APIRecord<JSONValue>>) async throws -> APIRecord<JSONValue>
}

struct TripService: TripServing {
    let client: APIClient
    let authentication: any AccessTokenProviding
    func list() async throws -> [APIRecord<Trip>] {
        let response: APIRecordList<Trip> = try await client.send(.get(.trips), using: authentication)
        return response.items.filter { !$0.deleted }
    }
    func load(_ id: UUID) async throws -> APIRecord<Trip> {
        try await client.send(.get(.trip(id)), using: authentication)
    }
    func save(_ request: APIRequest<APIRecord<Trip>>) async throws -> APIRecord<Trip> {
        try await client.send(request, using: authentication)
    }
    func delete(_ request: APIRequest<APIRecord<JSONValue>>) async throws -> APIRecord<JSONValue> {
        try await client.send(request, using: authentication)
    }
}
