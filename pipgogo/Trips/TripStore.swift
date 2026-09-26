import Foundation
import Observation

struct TripConflict {
    let existing: APIRecord<Trip>?
}

@MainActor
@Observable
final class TripStore {
    private(set) var items: [APIRecord<Trip>] = []
    private(set) var loaded = false
    private(set) var busy = false
    private(set) var errorMessage: String?
    private(set) var saveError: String?
    private(set) var hasDraft = false
    private(set) var draftID = UUID()
    private(set) var base: APIRecord<Trip>?
    var draft = Trip()
    private(set) var pending: APIRequest<APIRecord<Trip>>?
    private(set) var conflict: TripConflict?
    private(set) var pendingDeletion: APIRequest<APIRecord<JSONValue>>?
    private var removedIDs: Set<String> = []
    private let service: any TripServing
    private var generation = UUID()
    private var listOperation: Task<[APIRecord<Trip>], Error>?
    private var recordOperation: Task<APIRecord<Trip>, Error>?
    private var deleteOperation: Task<APIRecord<JSONValue>, Error>?

    init(service: any TripServing) { self.service = service }
    var canEdit: Bool { hasDraft && !busy && pending == nil && pendingDeletion == nil && conflict == nil }
    var isEditing: Bool { base != nil }
    var dirty: Bool { draft != (base?.data ?? Trip()) }
    var canSave: Bool { hasDraft && !busy && conflict == nil && pendingDeletion == nil && (pending != nil || base == nil || dirty) }
    var canDelete: Bool { canEdit && base != nil && !dirty }

    func load(refresh: Bool = false) async {
        guard !busy, !loaded || refresh else { return }
        busy = true
        errorMessage = nil
        let generation = generation
        let service = service
        let task = Task { try await service.list() }
        listOperation = task
        do {
            let records = try await task.value
            guard generation == self.generation else { return }
            let active = records.filter { !$0.deleted }
            removedIDs.formUnion(Set(items.map(\.id)).subtracting(active.map(\.id)))
            items = active.filter { !removedIDs.contains($0.id) }
            loaded = true
        } catch {
            guard generation == self.generation else { return }
            errorMessage = error.localizedDescription
        }
        busy = false
        listOperation = nil
    }

    func refreshTrip(_ id: String) async {
        guard !busy, let uuid = UUID(uuidString: id) else { return }
        busy = true
        errorMessage = nil
        let generation = generation
        let service = service
        let task = Task { try await service.load(uuid) }
        recordOperation = task
        do {
            let record = try await task.value
            guard generation == self.generation else { return }
            guard record.id == id, record.kind == "trip", !record.deleted else { throw APIClientError.invalidResponse }
            upsert(record)
        } catch {
            guard generation == self.generation else { return }
            if case APIClientError.rejected(let status, let failure, _) = error, status == 404, failure.code == "not_found" {
                remove(id)
                errorMessage = "This trip is no longer available."
            } else { errorMessage = error.localizedDescription }
        }
        busy = false
        recordOperation = nil
    }

    @discardableResult
    func beginCreation() -> Bool {
        guard !busy else { return false }
        if !hasDraft {
            draftID = UUID()
            base = nil
            draft = Trip()
            saveError = nil
            pending = nil
            conflict = nil
            hasDraft = true
        }
        return true
    }

    @discardableResult
    func beginEditing(_ id: String) -> Bool {
        guard !busy else { return false }
        if hasDraft { return draftID.uuidString.lowercased() == id && isEditing }
        guard let record = items.first(where: { $0.id == id }), let uuid = UUID(uuidString: id) else { return false }
        draftID = uuid
        base = record
        draft = record.data
        hasDraft = true
        saveError = nil
        return true
    }

    @discardableResult
    func save() async -> Bool {
        guard canSave else { return false }
        saveError = nil
        do {
            if pending == nil { pending = try .put(.trip(draftID), body: draft.validated(), expectedVersion: base?.version ?? 0) }
        } catch { saveError = error.localizedDescription; return false }
        guard let request = pending else { return false }
        busy = true
        let generation = generation
        let service = service
        let task = Task { try await service.save(request) }
        recordOperation = task
        var succeeded = false
        do {
            let record = try await task.value
            guard generation == self.generation else { return false }
            guard record.id == draftID.uuidString.lowercased(), record.kind == "trip", !record.deleted else { throw APIClientError.invalidResponse }
            upsert(record)
            clearDraft()
            succeeded = true
        } catch {
            guard generation == self.generation else { return false }
            handleSaveError(error)
        }
        busy = false
        recordOperation = nil
        return succeeded
    }

    /// The UI requires confirmation for each new deletion intent; uncertain retries reuse it.
    @discardableResult
    func delete() async -> Bool {
        guard canDelete || (hasDraft && !busy && pendingDeletion != nil && conflict == nil) else { return false }
        saveError = nil
        do {
            if pendingDeletion == nil { pendingDeletion = try .delete(.trip(draftID), expectedVersion: base?.version ?? 0) }
        } catch { saveError = error.localizedDescription; return false }
        guard let request = pendingDeletion else { return false }
        busy = true
        let generation = generation
        let service = service
        let task = Task { try await service.delete(request) }
        deleteOperation = task
        var succeeded = false
        do {
            let record = try await task.value
            guard generation == self.generation else { return false }
            guard record.id == draftID.uuidString.lowercased(), record.kind == "trip", record.deleted else { throw APIClientError.invalidResponse }
            remove(record.id)
            clearDraft()
            succeeded = true
        } catch {
            guard generation == self.generation else { return false }
            handleSaveError(error)
        }
        busy = false
        deleteOperation = nil
        return succeeded
    }

    private func handleSaveError(_ error: Error) {
        if case APIClientError.conflict(let failure, _) = error,
           failure.code == "version_conflict", let current = failure.details?["current"] {
            do {
                let existing: APIRecord<Trip>?
                if current == .null { existing = nil }
                else {
                    let raw = try current.decoded(as: APIRecord<JSONValue>.self)
                    guard raw.id == draftID.uuidString.lowercased(), raw.kind == "trip" else { throw APIClientError.invalidResponse }
                    existing = raw.deleted ? nil : try current.decoded(as: APIRecord<Trip>.self)
                }
                conflict = TripConflict(existing: existing)
                pending = nil
                pendingDeletion = nil
            } catch { saveError = "Could not read the existing trip. Your draft and original request are retained." }
            return
        }
        // The backend rejects a missing selected companion before committing the trip.
        if case APIClientError.rejected(let status, let failure, _) = error,
           [400, 422].contains(status) || (status == 404 && failure.code == "not_found") {
            pending = nil
            pendingDeletion = nil
            saveError = status == 404 ? "A selected companion is no longer available. Refresh companions and review your selection before saving again." : error.localizedDescription
        } else { saveError = error.localizedDescription }
    }

    /// A collision must never turn creation into an overwrite of an existing trip.
    func keepAsNewTrip() {
        guard !busy, let conflict else { return }
        if let existing = conflict.existing { upsert(existing) }
        else if isEditing { remove(draftID.uuidString.lowercased()) }
        base = nil
        draftID = UUID()
        pending = nil
        self.conflict = nil
        saveError = nil
    }

    /// Review updates the baseline only. Saving against it is a separate user action.
    func keepDraft() {
        guard !busy, isEditing, let existing = conflict?.existing else { return }
        base = existing
        upsert(existing)
        conflict = nil
        saveError = nil
    }

    func useExistingTrip() {
        guard !busy, let conflict else { return }
        if let existing = conflict.existing { upsert(existing) }
        else if isEditing { remove(draftID.uuidString.lowercased()) }
        clearDraft()
    }

    func discardDraft() {
        guard canEdit else { return }
        clearDraft()
    }

    private func remove(_ id: String) {
        removedIDs.insert(id)
        items.removeAll { $0.id == id }
    }
    private func upsert(_ record: APIRecord<Trip>) {
        guard !removedIDs.contains(record.id) else { return }
        // A replayed creation receipt may predate a record fetched during recovery.
        if let cached = items.first(where: { $0.id == record.id }), cached.revision > record.revision { return }
        items.removeAll { $0.id == record.id }
        items.append(record)
    }
    private func clearDraft() {
        draft = Trip()
        base = nil
        pendingDeletion = nil
        hasDraft = false
        pending = nil
        conflict = nil
        saveError = nil
    }
    func reset() {
        generation = UUID()
        listOperation?.cancel()
        recordOperation?.cancel()
        deleteOperation?.cancel()
        listOperation = nil
        recordOperation = nil
        deleteOperation = nil
        removedIDs = []
        items = []
        loaded = false
        busy = false
        errorMessage = nil
        clearDraft()
    }
}
