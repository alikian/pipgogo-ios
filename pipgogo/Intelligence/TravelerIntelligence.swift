import Foundation
import Observation

struct TripTraveler: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var saved_traveler_id: UUID? = nil
    var name = ""
    var relationship = ""
    var age_or_range = ""
    var language = ""
    var preferences = ""
    var needs = ""
    var needs_response = "not_asked"
}
struct FixedCommitment: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var title = ""
    var timing = ""
    var location = ""
    var reference = ""
    var fixed = true
    var source_reference: String? = nil
}
struct TripLodging: Codable, Equatable, Sendable {
    var property_name = ""
    var address = ""
    var check_in = ""
    var check_out = ""
    var reference = ""
    var instructions = ""
}
struct FlightSegment: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var direction = "outbound"
    var sequence = 1
    var airline = ""
    var flight_number = ""
    var departure_airport = ""
    var arrival_airport = ""
    var departure_local = ""
    var arrival_local = ""
    var departure_timezone = ""
    var arrival_timezone = ""
    var departure_terminal = ""
    var arrival_terminal = ""
    var booking_reference = ""
    var status = "booked"
}
struct GroundTransfer: Codable, Identifiable, Equatable, Sendable {
    var id: String { leg }
    var leg: String
    var mode = "not_sure"
    var arranged = false
    var pickup_point = ""
    var luggage = ""
    var duration_minutes: Int? = nil
    var airport_buffer_minutes = 120
    var baggage_minutes = 45
    var rest_minutes = 60
    var notes = ""
}
struct DoorToDoorTravel: Codable, Equatable, Sendable {
    var mode = "unknown"
    var booking_status = "unknown"
    var home = ""
    var departure_airport = ""
    var flights: [FlightSegment] = []
    var transfers: [GroundTransfer] = []
    static let legs = ["home_to_airport", "airport_to_hotel", "hotel_to_airport", "airport_to_home"]
    var flightSearchURL: URL {
        URL(string: "https://www.google.com/travel/flights")!
    }
    func flightSearchURL(destination: String, when: String, start: String?, end: String?) -> URL {
        var url = URLComponents(string: "https://www.google.com/travel/flights")!
        let origin = departure_airport.isEmpty ? home : departure_airport
        let dates = [start, end].compactMap { $0 }.joined(separator: " to ")
        url.queryItems = [URLQueryItem(name: "q", value: "Flights from \(origin) to \(destination) \(dates.isEmpty ? when : dates)")]
        return url.url ?? flightSearchURL
    }
}
struct TransferTiming: Codable, Identifiable, Equatable, Sendable {
    var id: String { leg }
    var leg: String
    var airport: String
    var time_zone: String
    var leave_at: String?
    var arrive_at: String?
    var provisional: Bool
}
struct DoorToDoorSummary: Codable, Equatable, Sendable {
    var provisional: Bool
    var legs: [TransferTiming]
    var windows: [String: String]
    var warnings: [String]
}
struct TripIntake: Codable, Equatable, Sendable {
    var door_to_door: DoorToDoorTravel? = nil
    var destination = ""
    var start_date: String? = nil
    var end_date: String? = nil
    var approximate_dates = ""
    var duration_days: Int? = 4
    var planning_state = "starting_from_scratch"
    var status = "intake_in_progress"
    var language = "en"
    var travelers: [TripTraveler] = []
    var transportation: [String] = []
    var transportation_notes = ""
    var lodging = TripLodging()
    var commitments: [FixedCommitment] = []
    var constraints = ""
    var existing_plans = ""
    var notes = ""
}
struct PipMessage: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var role: String
    var text: String
    var created_at: String
    var memory_observations: [String]?
}
struct PipPlanItem: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var timing: String
    var location: String
    var rationale: String
}
struct PipProposal: Codable, Equatable, Sendable {
    var id: String
    var items: [PipPlanItem]
    var explanation: String
    var created_at: String
}
struct ImportFact: Codable, Equatable, Sendable {
    var kind: String
    var title: String
    var details: String
    var timing: String
    var location: String
    var confidence: Double
}
struct TripImport: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var filename: String
    var status: String
    var created_at: String
    var explanation: String
    var facts: [ImportFact]
    var confirmed_facts: [ImportFact]
    var flights: [FlightSegment]? = nil
    var confirmed_flights: [FlightSegment]? = nil
}
struct Journey: Codable, Equatable, Sendable {
    var travel_summary: DoorToDoorSummary? = nil
    var plan_needs_review: Bool? = nil
    var intake: TripIntake
    var messages: [PipMessage]
    var plan: [PipPlanItem]
    var proposal: PipProposal?
    var imports: [TripImport]
    var onboarding_done: Bool
    var temporary_context: String
}
struct TravelerMemory: Codable, Equatable, Sendable {
    var category = "traveler_preference"
    var key = ""
    var value = ""
    var original_text = ""
    var confidence = 1.0
    var status = "explicit"
    var scope = "persistent"
    var trip_id: UUID? = nil
    var source_type = "traveler_correction"
    var source_reference: String? = nil
    var sensitive = false
}
struct PipAction: Codable, Sendable {
    var action: String
    var text = ""
    var proposal_id: String? = nil
    var import_id: String? = nil
    var facts: [ImportFact] = []
    var flights: [FlightSegment] = []
}
struct PipImportRequest: Codable, Sendable {
    var filename: String
    var text = ""
    var content_base64 = ""
}

/// Session-owned drafts and frozen mutations. Epoch fences ignore responses after sign-out.
@MainActor @Observable
final class IntelligenceStore {
    var journeys: [APIRecord<Journey>] = []
    var memories: [APIRecord<TravelerMemory>] = []
    var travelers: [APIRecord<TripTraveler>] = []
    var selectedID: UUID?
    var draft = TripIntake()
    var draftID = UUID()
    var draftVersion = 0
    var composer = ""
    var error: String?
    var busy = false
    var loaded = false
    var conflict: APIRecord<Journey>?
    private(set) var pending: APIRequest<APIRecord<Journey>>?
    private(set) var pendingAux: APIRequest<APIRecord<JSONValue>>?
    var hasPending: Bool { pending != nil || pendingAux != nil }
    private var epoch = UUID()
    private let client: APIClient
    private let authentication: any AccessTokenProviding

    init(client: APIClient, authentication: any AccessTokenProviding) {
        self.client = client; self.authentication = authentication
    }
    var selected: APIRecord<Journey>? { journeys.first { $0.id == selectedID?.uuidString.lowercased() } }
    var preferredName: String? {
        memories.sorted { $0.revision > $1.revision }.first { !$0.deleted && ["preferred_name", "nickname"].contains($0.data.key) &&
            ["explicit", "confirmed"].contains($0.data.status) && $0.data.scope == "persistent" &&
            !$0.data.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }?.data.value
    }
    func reset() {
        epoch = UUID(); journeys = []; memories = []; travelers = []; selectedID = nil
        draft = TripIntake(); draftID = UUID(); draftVersion = 0; composer = ""
        pending = nil; pendingAux = nil; conflict = nil; error = nil; busy = false; loaded = false
    }
    func refresh() async {
        guard !busy, !hasPending else { return }
        busy = true; let ticket = epoch
        defer { if ticket == epoch { busy = false } }
        do {
            let trips: APIRecordList<Journey> = try await client.send(.get(.journeys), using: authentication)
            let memory: APIRecordList<TravelerMemory> = try await client.send(.get(.memory), using: authentication)
            let party: APIRecordList<TripTraveler> = try await client.send(.get(.travelers), using: authentication)
            guard ticket == epoch else { return }
            journeys = trips.items; memories = memory.items; travelers = party.items; loaded = true; error = nil
        } catch { if ticket == epoch { self.error = error.localizedDescription } }
    }
    func newTrip(language: String) {
        guard !hasPending else { return }
        selectedID = nil
        draft = TripIntake(); draft.language = language; draftID = UUID(); draftVersion = 0; conflict = nil
    }
    func edit(_ record: APIRecord<Journey>) {
        guard !hasPending else { return }
        draft = record.data.intake; draftID = UUID(uuidString: record.id)!; draftVersion = record.version; conflict = nil
    }
    func saveIntake() async {
        guard !busy else { return }
        do {
            if pending == nil { pending = try .put(.journey(draftID), body: draft, expectedVersion: draftVersion) }
            await retry()
        } catch { self.error = error.localizedDescription }
    }
    func act(_ action: PipAction) async {
        guard !busy, !hasPending, let record = selected, let id = UUID(uuidString: record.id) else { return }
        do { pending = try .put(.journeyAction(id), body: action, expectedVersion: record.version); await retry() }
        catch { self.error = error.localizedDescription }
    }
    func importDetails(_ body: PipImportRequest) async {
        guard !busy, !hasPending, let record = selected, let id = UUID(uuidString: record.id) else { return }
        do { pending = try .put(.journeyImport(id), body: body, expectedVersion: record.version); await retry() }
        catch { self.error = error.localizedDescription }
    }
    func retry() async {
        guard !busy, let request = pending else { return }
        busy = true; error = nil; let ticket = epoch
        defer { if ticket == epoch { busy = false } }
        do {
            let result = try await client.send(request, using: authentication)
            guard ticket == epoch else { return }
            // A replayed receipt may be older than the server. Always refresh current state.
            let current: APIRecord<Journey> = try await client.send(.get(.journey(UUID(uuidString: result.id)!)), using: authentication)
            guard ticket == epoch else { return }
            let refreshedMemory: APIRecordList<TravelerMemory> = try await client.send(.get(.memory), using: authentication)
            guard ticket == epoch else { return }
            memories = refreshedMemory.items
            pending = nil; conflict = nil
            journeys.removeAll { $0.id == current.id }; journeys.insert(current, at: 0)
            selectedID = UUID(uuidString: current.id); draftVersion = current.version; composer = ""
        } catch APIClientError.conflict(let body, _) {
            guard ticket == epoch else { return }
            error = body.message
            conflict = try? body.currentRecord?.data.decoded(as: Journey.self).mapRecord(body.currentRecord!)
        } catch APIClientError.rejected(let status, let body, _) {
            guard ticket == epoch else { return }
            self.error = body.message
            if [400, 403, 404, 413, 422, 429].contains(status) || body.code == "ai_unavailable" { pending = nil }
        } catch { if ticket == epoch { self.error = error.localizedDescription } }
    }
    /// Deliberate review clears the failed operation; no automatic overwrite or action replay.
    func useServerAfterReview() {
        guard let conflict else { return }
        journeys.removeAll { $0.id == conflict.id }; journeys.insert(conflict, at: 0)
        draft = conflict.data.intake; draftVersion = conflict.version
        pending = nil; self.conflict = nil; error = nil
    }
    func keepDraftAfterReview() {
        guard let conflict else { return }
        journeys.removeAll { $0.id == conflict.id }; journeys.insert(conflict, at: 0)
        draftVersion = conflict.version; pending = nil; self.conflict = nil; error = nil
    }
    func saveMemory(_ memory: TravelerMemory, id: UUID = UUID(), version: Int = 0) async {
        guard !busy, !hasPending else { return }
        do { pendingAux = try .put(.memoryItem(id), body: memory, expectedVersion: version); await retryAux() }
        catch { self.error = error.localizedDescription }
    }
    func forget(_ item: APIRecord<TravelerMemory>) async {
        guard !busy, !hasPending, let id = UUID(uuidString: item.id) else { return }
        do { pendingAux = try .delete(.memoryItem(id), expectedVersion: item.version); await retryAux() }
        catch { self.error = error.localizedDescription }
    }
    func saveTraveler(_ traveler: TripTraveler) async {
        guard !busy, !hasPending else { return }
        do { pendingAux = try .put(.traveler(traveler.id), body: traveler, expectedVersion: 0); await retryAux() }
        catch { self.error = error.localizedDescription }
    }
    func retryAux() async {
        guard !busy, let request = pendingAux else { return }
        busy = true; let ticket = epoch
        defer { if ticket == epoch { busy = false } }
        do {
            _ = try await client.send(request, using: authentication)
            guard ticket == epoch else { return }
            let memory: APIRecordList<TravelerMemory> = try await client.send(.get(.memory), using: authentication)
            let party: APIRecordList<TripTraveler> = try await client.send(.get(.travelers), using: authentication)
            guard ticket == epoch else { return }
            memories = memory.items; travelers = party.items; pendingAux = nil; error = nil
        } catch APIClientError.conflict(let body, _) {
            guard ticket == epoch else { return }
            error = body.message; pendingAux = nil
            // The edit text remains in its sheet; reload and review before another write.
        } catch APIClientError.rejected(let status, let body, _) {
            guard ticket == epoch else { return }
            error = body.message
            if [400, 403, 404, 413, 422].contains(status) { pendingAux = nil }
        } catch { if ticket == epoch { self.error = error.localizedDescription } }
    }

}
private extension Journey {
    func mapRecord(_ r: APIRecord<JSONValue>) -> APIRecord<Journey> {
        APIRecord(id: r.id, kind: r.kind, version: r.version, revision: r.revision, updatedAt: r.updatedAt, deleted: r.deleted, data: self)
    }
}
