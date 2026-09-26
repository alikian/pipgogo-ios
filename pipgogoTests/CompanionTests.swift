import Foundation
import Testing
@testable import pipgogo

@MainActor
struct CompanionTests {
    @Test func listCreateEditClearAndDelete() async throws {
        let api = CompanionStub()
        let list = CompanionStore(service: api)
        await list.load()
        #expect(list.loaded && list.items.isEmpty)
        #expect(list.open())
        let editor = try #require(list.editor)
        let id = editor.id
        editor.draft = Companion(nickname: "  Sam  ", relationship: "Friend", ageRange: "30–39", preferences: TravelerPreferences(languages: ["English"], interests: ["Art"], dietaryNeeds: ["Vegetarian"], accessibilityNeeds: ["Step-free"], pace: "relaxed", budgetComfort: "moderate", transportation: ["Train"]))
        await editor.save()
        #expect(list.items.count == 1)
        #expect(list.items.first?.data.nickname == "Sam")
        let reloaded = CompanionStore(service: api)
        await reloaded.load()
        #expect(reloaded.items == list.items)
        #expect(reloaded.open(reloaded.items.first))
        let editing = try #require(reloaded.editor)
        #expect(editing.id == id)
        editing.draft = Companion()
        await editing.save()
        #expect(reloaded.items.first?.data == Companion())
        let requests = await api.requests
        #expect(requests[0].expectedVersion == 0)
        #expect(requests[1].expectedVersion == 1)
        #expect(requests[0].endpoint == requests[1].endpoint)
        let body = try APIJSON.decoder().decode(JSONValue.self, from: #require(requests[1].body))
        #expect(body["relationship"] == nil)
        #expect(body["preferences"]?["dietary_needs"] == .array([]))
        await editing.delete()
        #expect(reloaded.items.isEmpty && editing.finished)
        #expect(await api.requests.last?.expectedVersion == 2)
        #expect(await api.requests.last?.method == "DELETE")
    }

    @Test func lostCreateResponseReusesIdentityAndFreezesDraft() async throws {
        let api = CompanionStub(failures: [.connection])
        let list = CompanionStore(service: api)
        list.open()
        let editor = try #require(list.editor)
        editor.draft.nickname = "Keep me"
        await editor.save()
        let pending = try #require(editor.pending)
        #expect(!editor.canEdit && !list.canOpenAnother)
        #expect(!list.open())
        editor.discardChanges()
        #expect(editor.draft.nickname == "Keep me")
        await editor.save()
        let requests = await api.requests
        #expect(requests.count == 2)
        #expect(requests[1].endpoint == pending.endpoint)
        #expect(requests[1].body == pending.body)
        #expect(requests[1].idempotencyKey == pending.idempotencyKey)
        #expect(requests[1].expectedVersion == 0)
        #expect(list.items.count == 1)
    }

    @Test func uncertainDeletionRetriesOriginalRequestAndDecodesEmptyTombstone() async throws {
        let original = record()
        let api = CompanionStub(failures: [.connection])
        let editor = CompanionEditorStore(service: api, record: original)
        await editor.delete()
        let pending = try #require(editor.pending)
        #expect(!editor.finished && !editor.canEdit && !editor.canSave)
        await editor.save()
        #expect(await api.requests.count == 1)
        await editor.delete()
        let last = try #require(await api.requests.last)
        #expect(last.idempotencyKey == pending.idempotencyKey)
        #expect(last.expectedVersion == pending.expectedVersion)
        #expect(last.endpoint == pending.endpoint && last.body == nil)
        #expect(editor.finished)
    }

    @Test func inUseRejectionKeepsCompanionAndAllowsCorrection() async {
        let failure = APIClientError.conflict(APIErrorBody(code: "companion_in_use", message: "Remove the companion from trips first"), requestID: nil)
        let original = record()
        let editor = CompanionEditorStore(service: CompanionStub(failures: [failure]), record: original)
        await editor.delete()
        #expect(editor.saved == original)
        #expect(editor.draft == original.data)
        #expect(editor.pending == nil && editor.canEdit && !editor.finished)
        #expect(editor.errorMessage?.contains("active trip") == true)
    }

    @Test func conflictKeepsDraftUntilExplicitReviewThenUsesNewKeyAndVersion() async throws {
        let original = record()
        let remote = record(id: UUID(uuidString: original.id)!, version: 2, name: "Changed elsewhere")
        let api = CompanionStub(failures: [try conflict(remote)])
        let editor = CompanionEditorStore(service: api, record: original)
        editor.draft.nickname = "My edit"
        await editor.save()
        #expect(editor.draft.nickname == "My edit")
        #expect(editor.conflict?.saved == remote)
        await editor.save()
        #expect(await api.requests.count == 1)
        editor.keepDraft()
        #expect(await api.requests.count == 1)
        await editor.save()
        let requests = await api.requests
        #expect(requests.last?.expectedVersion == 2)
        #expect(requests.first?.idempotencyKey != requests.last?.idempotencyKey)
    }

    @Test func deletionConflictDoesNotAutomaticallyDeleteChangedRecord() async throws {
        let original = record()
        let remote = record(id: UUID(uuidString: original.id)!, version: 2, name: "New name")
        let api = CompanionStub(failures: [try conflict(remote)])
        let editor = CompanionEditorStore(service: api, record: original)
        await editor.delete()
        #expect(editor.conflict?.saved == remote)
        await editor.delete()
        #expect(await api.requests.count == 1)
        editor.useSaved()
        #expect(editor.draft.nickname == "New name" && editor.canDelete)
        #expect(await api.requests.count == 1)
        await editor.delete()
        #expect(await api.requests.last?.expectedVersion == 2)
        #expect(editor.finished)
    }

    @Test func remotelyDeletedCompanionBecomesNewIdentityOnlyOnExplicitChoice() async throws {
        let original = record()
        let tombstone = APIRecord(id: original.id, kind: "companion", version: 2, revision: 2, updatedAt: Date(), deleted: true, data: JSONValue.object([:]))
        let api = CompanionStub(failures: [try conflict(tombstone)])
        let editor = CompanionEditorStore(service: api, record: original)
        editor.draft.nickname = "Preserved edit"
        await editor.save()
        #expect(editor.conflict?.removed == true)
        #expect(editor.id.uuidString.lowercased() == original.id)
        editor.keepDraft()
        #expect(editor.id.uuidString.lowercased() != original.id)
        #expect(editor.draft.nickname == "Preserved edit")
        #expect(await api.requests.count == 1)
        await editor.save()
        #expect(await api.requests.last?.expectedVersion == 0)
    }

    @Test func acceptingRemoteRemovalDoesNotWriteOrRetainListEntry() async throws {
        let original = record()
        let failure = APIClientError.conflict(APIErrorBody(code: "version_conflict", message: "Missing", details: .object(["current": .null])), requestID: nil)
        let api = CompanionStub(existing: [original], failures: [failure])
        let list = CompanionStore(service: api)
        await list.load()
        list.open(original)
        let editor = try #require(list.editor)
        await editor.delete()
        editor.useSaved()
        #expect(editor.finished && list.items.isEmpty)
        #expect(await api.requests.count == 1)
    }

    @Test func navigationAndRefreshDoNotDiscardOpenDraft() async throws {
        let original = record()
        let api = CompanionStub(existing: [original])
        let list = CompanionStore(service: api)
        await list.load()
        list.open(original)
        let editor = try #require(list.editor)
        editor.draft.nickname = "Draft"
        await list.load(refresh: true)
        #expect(list.open(original))
        #expect(list.editor === editor)
        #expect(editor.draft.nickname == "Draft")
        #expect(!list.open())
        #expect(!editor.canDelete)
        editor.discardChanges()
        #expect(editor.draft.nickname == original.data.nickname && editor.canDelete)
        #expect(list.open())
    }

    @Test func validationFailurePreservesEditableDraft() async {
        let api = CompanionStub()
        let editor = CompanionEditorStore(service: api)
        editor.draft.relationship = String(repeating: "a", count: 301)
        await editor.save()
        #expect(editor.canEdit && editor.pending == nil)
        #expect(await api.requests.isEmpty)
        #expect(editor.draft.relationship?.count == 301)
    }

    @Test func serverValidationRejectionCanBeCorrected() async {
        let failure = APIClientError.rejected(status: 422, error: APIErrorBody(code: "validation_error", message: "Invalid request"), requestID: nil)
        let editor = CompanionEditorStore(service: CompanionStub(failures: [failure]))
        editor.draft.nickname = "Keep"
        await editor.save()
        #expect(editor.canEdit && editor.pending == nil && editor.draft.nickname == "Keep")
    }

    @Test func listFailureShowsRetryAndPreservesLoadedRecords() async {
        let api = CompanionStub(existing: [record()])
        let store = CompanionStore(service: api)
        await store.load()
        await api.failList()
        await store.load(refresh: true)
        #expect(store.loaded && store.items.count == 1 && store.errorMessage != nil)
        let initial = CompanionStore(service: api)
        await initial.load()
        #expect(!initial.loaded && initial.errorMessage != nil)
    }

    @Test func resetDiscardsDraftAndLateWriteFromPreviousAccount() async {
        let api = DelayedCompanion()
        let list = CompanionStore(service: api)
        list.open()
        let editor = list.editor!
        editor.draft.nickname = "Old account"
        let saving = Task { await editor.save() }
        while !(await api.started) { await Task.yield() }
        list.reset()
        await api.finish()
        #expect(await saving.value == false)
        #expect(list.items.isEmpty && list.editor == nil && !list.loaded)
        #expect(editor.draft == Companion() && !editor.canSave)
    }

    private func record(id: UUID = UUID(), version: Int = 1, name: String = "Sam") -> APIRecord<Companion> {
        APIRecord(id: id.uuidString.lowercased(), kind: "companion", version: version, revision: version, updatedAt: Date(timeIntervalSince1970: 1_800_000_000), deleted: false, data: Companion(nickname: name))
    }
    private func conflict<T>(_ record: APIRecord<T>) throws -> APIClientError {
        let current = try APIJSON.decoder().decode(JSONValue.self, from: APIJSON.encoder().encode(record))
        return .conflict(APIErrorBody(code: "version_conflict", message: "Changed", details: .object(["current": current])), requestID: nil)
    }
}

private actor CompanionStub: CompanionServing {
    var existing: [APIRecord<Companion>]
    var failures: [APIClientError]
    var requests: [APIRequest<APIRecord<JSONValue>>] = []
    var listFails = false
    init(existing: [APIRecord<Companion>] = [], failures: [APIClientError] = []) { self.existing = existing; self.failures = failures }
    func failList() { listFails = true }
    func list() async throws -> [APIRecord<Companion>] {
        if listFails { throw APIClientError.connection }
        return existing
    }
    func mutate(_ request: APIRequest<APIRecord<JSONValue>>) async throws -> APIRecord<JSONValue> {
        requests.append(request)
        if !failures.isEmpty { throw failures.removeFirst() }
        guard case .companion(let id) = request.endpoint else { throw APIClientError.invalidRequest("Wrong endpoint") }
        let deleted = request.method == "DELETE"
        let data = try request.body.map { try APIJSON.decoder().decode(JSONValue.self, from: $0) } ?? .object([:])
        let record = APIRecord(id: id.uuidString.lowercased(), kind: "companion", version: request.expectedVersion! + 1, revision: 1, updatedAt: Date(), deleted: deleted, data: data)
        existing.removeAll { $0.id == record.id }
        if !deleted { existing.append(try record.companion()) }
        return record
    }
}

private actor DelayedCompanion: CompanionServing {
    var continuation: CheckedContinuation<APIRecord<JSONValue>, Never>?
    var request: APIRequest<APIRecord<JSONValue>>?
    var started = false
    func list() async throws -> [APIRecord<Companion>] { [] }
    func mutate(_ request: APIRequest<APIRecord<JSONValue>>) async throws -> APIRecord<JSONValue> {
        self.request = request
        return await withCheckedContinuation { continuation = $0; started = true }
    }
    func finish() {
        guard let request, case .companion(let id) = request.endpoint else { return }
        let data = try! APIJSON.decoder().decode(JSONValue.self, from: request.body!)
        continuation?.resume(returning: APIRecord(id: id.uuidString.lowercased(), kind: "companion", version: 1, revision: 1, updatedAt: Date(), deleted: false, data: data))
        continuation = nil
    }
}
