import Foundation
import Observation

@MainActor
@Observable
final class CompanionStore {
    private(set) var items: [APIRecord<Companion>] = []
    private(set) var loaded = false
    private(set) var busy = false
    private(set) var errorMessage: String?
    private(set) var editor: CompanionEditorStore?
    private let service: any CompanionServing
    private var generation = UUID()
    private var operation: Task<[APIRecord<Companion>], Error>?

    init(service: any CompanionServing) { self.service = service }
    var canOpenAnother: Bool { !busy && (editor?.canLeave ?? true) }

    func load(refresh: Bool = false) async {
        guard !busy, !loaded || refresh else { return }
        // Serialize list requests with writes; an older list cannot undo a successful edit.
        guard editor?.busy != true else { return }
        busy = true
        errorMessage = nil
        let generation = generation
        let service = service
        let task = Task { try await service.list() }
        operation = task
        do {
            let records = try await task.value
            guard generation == self.generation else { return }
            items = records.filter { !$0.deleted }
            loaded = true
        } catch {
            guard generation == self.generation else { return }
            errorMessage = error.localizedDescription
        }
        busy = false
        operation = nil
    }

    @discardableResult
    func open(_ record: APIRecord<Companion>? = nil) -> Bool {
        guard !busy else { return false }
        if let editor, !editor.finished, let record, editor.id.uuidString.lowercased() == record.id { return true }
        guard canOpenAnother else { return false }
        if let record, UUID(uuidString: record.id) == nil { errorMessage = "This companion has an invalid identifier."; return false }
        editor?.reset()
        editor = CompanionEditorStore(service: service, record: record) { [weak self] id, record in
            guard let self else { return }
            self.items.removeAll { $0.id == id.uuidString.lowercased() }
            if let record { self.items.append(record) }
        }
        return true
    }

    func reset() {
        generation = UUID()
        operation?.cancel()
        operation = nil
        editor?.reset()
        editor = nil
        items = []
        loaded = false
        busy = false
        errorMessage = nil
    }
}

struct CompanionConflict {
    let saved: APIRecord<Companion>?
    var removed: Bool { saved == nil }
}

@MainActor
@Observable
final class CompanionEditorStore {
    private(set) var id: UUID
    var draft: Companion
    private(set) var saved: APIRecord<Companion>?
    private(set) var busy = false
    private(set) var finished = false
    private(set) var errorMessage: String?
    private(set) var notice: String?
    private(set) var conflict: CompanionConflict?
    private(set) var pending: APIRequest<APIRecord<JSONValue>>?
    private let service: any CompanionServing
    private let changed: (UUID, APIRecord<Companion>?) -> Void
    private var generation = UUID()
    private var active = true
    private var operation: Task<APIRecord<JSONValue>, Error>?

    init(service: any CompanionServing, record: APIRecord<Companion>? = nil, changed: @escaping (UUID, APIRecord<Companion>?) -> Void = { _, _ in }) {
        self.service = service
        self.saved = record
        self.id = record.flatMap { UUID(uuidString: $0.id) } ?? UUID()
        self.draft = record?.data ?? Companion()
        self.changed = changed
    }

    var dirty: Bool { draft != (saved?.data ?? Companion()) }
    var canEdit: Bool { active && !finished && !busy && pending == nil && conflict == nil }
    var canLeave: Bool { finished || (canEdit && !dirty) }
    var canSave: Bool { active && !finished && !busy && conflict == nil && (pending?.method == "PUT" || (pending == nil && (dirty || saved == nil))) }
    var canDelete: Bool { canEdit && saved != nil && !dirty }

    @discardableResult
    func save() async -> Bool {
        guard canSave else { return false }
        do {
            if pending == nil { pending = try .put(.companion(id), body: draft.validated(), expectedVersion: saved?.version ?? 0) }
        } catch { errorMessage = error.localizedDescription; return false }
        return await submit()
    }

    /// Called only after the user confirms deletion, or explicitly retries the same deletion.
    func delete() async {
        guard canDelete || (active && !finished && !busy && pending?.method == "DELETE") else { return }
        do {
            if pending == nil { pending = try .delete(.companion(id), expectedVersion: saved?.version ?? 0) }
        } catch { errorMessage = error.localizedDescription; return }
        _ = await submit()
    }

    private func submit() async -> Bool {
        guard let request = pending else { return false }
        busy = true
        errorMessage = nil
        notice = nil
        let generation = generation
        let service = service
        let task = Task { try await service.mutate(request) }
        operation = task
        var succeeded = false
        do {
            let result = try await task.value
            guard generation == self.generation else { return false }
            guard result.id == id.uuidString.lowercased(), result.kind == "companion",
                  result.deleted == (request.method == "DELETE") else { throw APIClientError.invalidResponse }
            if result.deleted {
                finished = true
                changed(id, nil)
            } else {
                let record = try result.companion()
                saved = record
                draft = record.data
                changed(id, record)
                notice = "Companion saved."
            }
            pending = nil
            succeeded = true
        } catch {
            guard generation == self.generation else { return false }
            handle(error)
        }
        busy = false
        operation = nil
        return succeeded
    }

    private func handle(_ error: Error) {
        if case APIClientError.conflict(let failure, _) = error {
            if failure.code == "companion_in_use" {
                pending = nil
                errorMessage = "This companion is included in an active trip. Remove them from every active trip before deleting them. Open Trips, edit each trip, and deselect this companion."
                return
            }
            if failure.code == "version_conflict", let current = failure.details?["current"] {
                do {
                    let remote: APIRecord<Companion>?
                    if current == .null { remote = nil }
                    else {
                        let raw = try current.decoded(as: APIRecord<JSONValue>.self)
                        guard raw.id == id.uuidString.lowercased(), raw.kind == "companion" else { throw APIClientError.invalidResponse }
                        remote = raw.deleted ? nil : try raw.companion()
                    }
                    pending = nil
                    conflict = CompanionConflict(saved: remote)
                    return
                } catch {
                    errorMessage = "Could not read the changed companion. Your draft and original request are retained."
                    return
                }
            }
        }
        // Only definite validation rejection permits a new operation. Uncertain outcomes
        // keep the exact UUID, body, key and version, for both saves and deletions.
        if case APIClientError.rejected(let status, _, _) = error, [400, 422].contains(status) { pending = nil }
        errorMessage = error.localizedDescription
    }

    func keepDraft() {
        guard active, !busy, let conflict else { return }
        if conflict.removed {
            changed(id, nil)
            id = UUID() // A tombstone can never be resurrected; a deliberate copy is a new companion.
        }
        saved = conflict.saved
        self.conflict = nil
        errorMessage = nil
        notice = conflict.removed ? "Your draft is kept as a new companion. Save when ready." : "Your draft is kept. Review it before saving or confirming deletion again."
    }

    func useSaved() {
        guard active, !busy, let conflict else { return }
        saved = conflict.saved
        draft = conflict.saved?.data ?? Companion()
        finished = conflict.removed
        changed(id, conflict.saved)
        self.conflict = nil
        errorMessage = nil
        notice = "Using the saved companion."
    }

    func discardChanges() {
        guard canEdit else { return }
        draft = saved?.data ?? Companion()
        finished = saved == nil
        errorMessage = nil
        notice = nil
    }

    func reset() {
        generation = UUID()
        active = false
        operation?.cancel()
        operation = nil
        draft = Companion()
        saved = nil
        pending = nil
        conflict = nil
        errorMessage = nil
        notice = nil
        busy = false
        finished = true
    }
}
