import Foundation
import Observation

struct CheckInInput: Codable, Equatable, Sendable {
    let confirmedTripVersion: Int
    let requests: String?
    let concerns: String?
    var needsReconfirmed = false
    enum CodingKeys: String, CodingKey {
        case requests, concerns
        case confirmedTripVersion = "confirmed_trip_version", needsReconfirmed = "needs_reconfirmed"
    }
}

struct TripCheckIn: Codable, Equatable, Sendable {
    let confirmedTripVersion: Int
    let requests: String?
    let concerns: String?
    let needsReconfirmed: Bool
    let tripID: String
    let refresh: CheckInRefresh
    enum CodingKeys: String, CodingKey {
        case requests, concerns, refresh
        case confirmedTripVersion = "confirmed_trip_version", needsReconfirmed = "needs_reconfirmed", tripID = "trip_id"
    }
}

struct CheckInRefresh: Codable, Equatable, Sendable {
    let status: String
    let attemptedAt: Date
    let missingCategories: [String]
    let warnings: [String]
    let observations: [JSONValue]
    enum CodingKeys: String, CodingKey {
        case status, warnings, observations
        case attemptedAt = "attempted_at", missingCategories = "missing_categories"
    }
}

struct CheckInContext: Sendable {
    let trip: APIRecord<Trip>
    let checkIn: APIRecord<TripCheckIn>?
}

protocol CheckInServing: Sendable {
    func load(_ id: UUID) async throws -> CheckInContext
    func save(_ request: APIRequest<APIRecord<TripCheckIn>>) async throws -> APIRecord<TripCheckIn>
}

struct CheckInService: CheckInServing {
    let client: APIClient
    let authentication: any AccessTokenProviding
    func load(_ id: UUID) async throws -> CheckInContext {
        let checkIn: APIRecord<TripCheckIn>?
        do { checkIn = try await client.send(.get(.checkIn(id)), using: authentication) }
        catch APIClientError.rejected(status: 404, error: let error, requestID: _) where error.code == "not_found" { checkIn = nil }
        // A missing check-in is an empty state only when the parent trip still exists.
        let trip: APIRecord<Trip> = try await client.send(.get(.trip(id)), using: authentication)
        return CheckInContext(trip: trip, checkIn: checkIn)
    }
    func save(_ request: APIRequest<APIRecord<TripCheckIn>>) async throws -> APIRecord<TripCheckIn> {
        try await client.send(request, using: authentication)
    }
}

@MainActor @Observable
final class CheckInCollection {
    private let service: any CheckInServing
    private var stores: [UUID: CheckInStore] = [:]
    init(service: any CheckInServing) { self.service = service }
    func store(for id: UUID) -> CheckInStore {
        if let store = stores[id] { return store }
        let store = CheckInStore(id: id, service: service)
        stores[id] = store
        return store
    }
    func reset() { stores.values.forEach { $0.reset() }; stores.removeAll() }
}

@MainActor @Observable
final class CheckInStore {
    let id: UUID
    private let service: any CheckInServing
    private var generation = UUID()
    private var loadTask: Task<CheckInContext, Error>?
    private var saveTask: Task<APIRecord<TripCheckIn>, Error>?
    private var initialized = false
    private(set) var trip: APIRecord<Trip>?
    private(set) var saved: APIRecord<TripCheckIn>?
    private(set) var loaded = false
    private(set) var busy = false
    private(set) var errorMessage: String?
    private(set) var pending: APIRequest<APIRecord<TripCheckIn>>?
    private(set) var hasConflict = false
    private(set) var conflicting: APIRecord<TripCheckIn>?
    var requests = ""
    var concerns = ""
    var confirmed = false

    init(id: UUID, service: any CheckInServing) { self.id = id; self.service = service }
    var canEdit: Bool { loaded && !busy && pending == nil && !hasConflict }
    var canSave: Bool { !busy && (pending != nil || (canEdit && confirmed)) }
    var dirty: Bool { requests != (saved?.data.requests ?? "") || concerns != (saved?.data.concerns ?? "") }
    var isCurrent: Bool { loaded && saved != nil && saved?.data.confirmedTripVersion == trip?.version && saved?.data.needsReconfirmed == false }

    func load() async {
        guard !busy else { return }
        let token = generation
        let preserve = initialized && (dirty || pending != nil || hasConflict)
        busy = true; loaded = false; confirmed = false; errorMessage = nil
        let task = Task { try await service.load(id) }
        loadTask = task
        do {
            let context = try await task.value
            guard generation == token else { return }
            guard context.trip.id == id.uuidString.lowercased(), context.trip.kind == "trip", !context.trip.deleted, context.trip.version > 0 else { throw APIClientError.invalidResponse }
            if let record = context.checkIn { try validate(record) }
            trip = context.trip
            if !preserve { saved = context.checkIn; hydrate() }
            initialized = true; loaded = true
        } catch {
            guard generation == token else { return }
            errorMessage = "Could not load current trip context. Your notes are kept. \(error.localizedDescription)"
        }
        guard generation == token else { return }
        busy = false; loadTask = nil
    }

    func save() async {
        guard canSave else { return }
        if pending == nil {
            guard let trip else { return }
            guard requests.unicodeScalars.count <= 2000, concerns.unicodeScalars.count <= 2000 else {
                errorMessage = "Requests and concerns must each be at most 2,000 characters."; return
            }
            do {
                let body = CheckInInput(confirmedTripVersion: trip.version, requests: optional(requests), concerns: optional(concerns))
                pending = try .put(.checkIn(id), body: body, expectedVersion: saved?.version ?? 0)
            } catch { errorMessage = error.localizedDescription; return }
        }
        guard let pending else { return }
        let token = generation
        busy = true; errorMessage = nil
        let task = Task { try await service.save(pending) }
        saveTask = task
        var refresh = false
        do {
            let result = try await task.value
            guard generation == token else { return }
            try validate(result)
            saved = result; self.pending = nil; hydrate(); confirmed = false
            refresh = true
        } catch {
            guard generation == token else { return }
            errorMessage = error.localizedDescription
            switch error {
            case APIClientError.conflict(let body, _) where body.code == "trip_changed":
                self.pending = nil; confirmed = false; loaded = false
                errorMessage = "The trip changed. Refresh and review its latest details, then confirm again. Your notes are kept."
            case APIClientError.conflict(let body, _) where body.code == "version_conflict":
                do {
                    guard let current = body.details?["current"] else { throw APIClientError.invalidResponse }
                    let record: APIRecord<TripCheckIn>?
                    if current == .null { record = nil } else { record = try current.decoded(as: APIRecord<TripCheckIn>.self) }
                    if let record { try validate(record) }
                    conflicting = record; hasConflict = true; self.pending = nil; confirmed = false
                } catch { errorMessage = "Could not read the conflict safely. Retry the unchanged request." }
            case APIClientError.rejected(let status, _, _) where [400, 404, 422].contains(status):
                self.pending = nil
                if status == 404 { loaded = false; confirmed = false }
            default: break // Unknown outcomes retain the exact request, key and version.
            }
        }
        guard generation == token else { return }
        busy = false; saveTask = nil
        // Receipts can be older than later edits. Always reload before claiming current confirmation.
        if refresh { await load() }
    }

    func resolveConflict(useSaved: Bool) async {
        guard hasConflict, !busy else { return }
        saved = conflicting
        if useSaved { hydrate() }
        conflicting = nil; hasConflict = false; confirmed = false
        await load()
    }
    func reset() {
        generation = UUID(); loadTask?.cancel(); saveTask?.cancel(); loadTask = nil; saveTask = nil
        trip = nil; saved = nil; pending = nil; conflicting = nil; hasConflict = false
        requests = ""; concerns = ""; confirmed = false; loaded = false; busy = false; initialized = false; errorMessage = nil
    }
    private func hydrate() { requests = saved?.data.requests ?? ""; concerns = saved?.data.concerns ?? "" }
    private func optional(_ value: String) -> String? { value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : value }
    private func validate(_ record: APIRecord<TripCheckIn>) throws {
        guard record.id == id.uuidString.lowercased(), record.kind == "checkin", !record.deleted, record.version > 0,
              record.data.tripID == id.uuidString.lowercased() else { throw APIClientError.invalidResponse }
    }
}
