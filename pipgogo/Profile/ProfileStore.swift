import Foundation
import Observation

struct ProfileConflict {
    let saved: APIRecord<TravelerProfile>?
}

@MainActor
@Observable
final class ProfileStore {
    var draft = TravelerProfile()
    private(set) var saved: APIRecord<TravelerProfile>?
    private(set) var loaded = false
    private(set) var busy = false
    private(set) var errorMessage: String?
    private(set) var notice: String?
    private(set) var conflict: ProfileConflict?
    private(set) var pending: APIRequest<APIRecord<TravelerProfile>>?
    private let service: any ProfileServing
    private var generation = UUID()
    private var operation: Task<APIRecord<TravelerProfile>?, Error>?

    init(service: any ProfileServing) { self.service = service }
    var dirty: Bool { draft != (saved?.data ?? TravelerProfile()) }
    var canEdit: Bool { loaded && !busy && pending == nil && conflict == nil }
    var canSave: Bool { loaded && !busy && conflict == nil && (pending != nil || dirty || saved == nil) }

    func load() async {
        guard !loaded, !busy else { return }
        busy = true
        errorMessage = nil
        let generation = generation
        let service = service
        let task = Task { try await service.load() }
        operation = task
        do {
            let record = try await task.value
            guard generation == self.generation else { return }
            saved = record
            draft = record?.data ?? TravelerProfile()
            loaded = true
        } catch {
            guard generation == self.generation else { return }
            errorMessage = error.localizedDescription
        }
        busy = false
        operation = nil
    }

    func save() async {
        guard canSave else { return }
        errorMessage = nil
        notice = nil
        do {
            if pending == nil {
                let body = try draft.validated()
                pending = try .put(.profile, body: body, expectedVersion: saved?.version ?? 0)
            }
        } catch { errorMessage = error.localizedDescription; return }
        guard let request = pending else { return }
        busy = true
        let generation = generation
        let service = service
        let task = Task<APIRecord<TravelerProfile>?, Error> { try await service.save(request) }
        operation = task
        do {
            let record = try await task.value
            guard generation == self.generation else { return }
            guard let record else { throw APIClientError.invalidResponse }
            saved = record
            draft = record.data
            pending = nil
            notice = "Profile saved."
        } catch {
            guard generation == self.generation else { return }
            if case APIClientError.conflict(let failure, _) = error,
               failure.code == "version_conflict", let current = failure.details?["current"] {
                if current == .null {
                    pending = nil
                    conflict = ProfileConflict(saved: nil)
                } else if let record = try? current.decoded(as: APIRecord<TravelerProfile>.self), !record.deleted {
                    pending = nil
                    conflict = ProfileConflict(saved: record)
                } else { errorMessage = "Could not read the newer profile. Your draft and original save request are retained." }
            } else {
                // Definite request rejection can be corrected. Network/5xx/decoding outcomes
                // remain uncertain, so retain and freeze the exact request for a safe retry.
                if case APIClientError.rejected(let status, _, _) = error, [400, 422].contains(status) { pending = nil }
                errorMessage = error.localizedDescription
            }
        }
        busy = false
        operation = nil
    }

    /// User has reviewed both values; rebase the draft but do not submit automatically.
    func keepDraft() {
        guard let conflict, !busy else { return }
        saved = conflict.saved
        self.conflict = nil
        pending = nil
        errorMessage = nil
        notice = "Your draft is kept. Review it, then Save to replace the saved profile."
    }

    func useSavedProfile() {
        guard let conflict, !busy else { return }
        saved = conflict.saved
        draft = conflict.saved?.data ?? TravelerProfile()
        self.conflict = nil
        pending = nil
        errorMessage = nil
        notice = "Using the saved profile."
    }

    func discardChanges() {
        guard !busy, pending == nil, conflict == nil else { return }
        draft = saved?.data ?? TravelerProfile()
        notice = nil
        errorMessage = nil
    }

    func reset() {
        generation = UUID()
        operation?.cancel()
        operation = nil
        draft = TravelerProfile()
        saved = nil
        loaded = false
        busy = false
        errorMessage = nil
        notice = nil
        conflict = nil
        pending = nil
    }
}
