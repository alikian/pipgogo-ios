import Foundation
import Testing
@testable import pipgogo

@MainActor
struct ProfileTests {
    private func record(_ body: TravelerProfile, version: Int = 1) -> APIRecord<TravelerProfile> {
        APIRecord(id: "me", kind: "profile", version: version, revision: version, updatedAt: .now, deleted: false, data: body)
    }

    @Test func missingProfileStartsOptionalEmptyEditor() async {
        let store = ProfileStore(service: ProfileStub())
        await store.load()
        #expect(store.loaded)
        #expect(store.saved == nil)
        #expect(store.draft == TravelerProfile())
        #expect(store.canEdit && store.canSave)
    }

    @Test func savingAndReloadingPreservesAllPreferencesAndVersion() async throws {
        let api = ProfileStub()
        let store = ProfileStore(service: api)
        await store.load()
        store.draft.nickname = "  Traveler  "
        store.draft.homeBase = "San Diego"
        store.draft.ageRange = "30–39"
        store.draft.usualParty = "others"
        store.draft.preferences = TravelerPreferences(languages: ["English"], interests: ["Art"], dietaryNeeds: ["Vegetarian"], accessibilityNeeds: ["Step-free"], pace: "relaxed", budgetComfort: "moderate", transportation: ["Train"])
        await store.save()
        #expect(store.saved?.version == 1)
        #expect(store.draft.nickname == "Traveler")
        #expect(!store.dirty)
        #expect(await api.requests.first?.expectedVersion == 0)
        let reopened = ProfileStore(service: api)
        await reopened.load()
        #expect(reopened.draft == store.draft)
        reopened.draft.nickname = "Updated"
        await reopened.save()
        #expect(reopened.saved?.version == 2)
        #expect(await api.requests.last?.expectedVersion == 1)
    }

    @Test func clearingFieldsSendsReplacementWithoutOldValues() async throws {
        let original = TravelerProfile(nickname: "Name", homeBase: "City", ageRange: "30–39", usualParty: "alone", preferences: TravelerPreferences(languages: ["French"], dietaryNeeds: ["Vegetarian"], pace: "active"))
        let api = ProfileStub(existing: record(original))
        let store = ProfileStore(service: api)
        await store.load()
        store.draft = TravelerProfile()
        await store.save()
        let request = try #require(await api.requests.first)
        let body = try APIJSON.decoder().decode(JSONValue.self, from: #require(request.body))
        #expect(body["home_base"] == nil)
        #expect(body["nickname"] == nil)
        #expect(body["preferences"]?["languages"] == .array([]))
        #expect(body["preferences"]?["dietary_needs"] == .array([]))
        #expect(store.saved?.data == TravelerProfile())
    }

    @Test func uncertainSaveRetainsDraftAndExactRequestUntilRetry() async throws {
        let api = ProfileStub(failures: [.connection])
        let store = ProfileStore(service: api)
        await store.load()
        store.draft.nickname = "Keep this"
        await store.save()
        let pending = try #require(store.pending)
        #expect(store.draft.nickname == "Keep this")
        #expect(!store.canEdit && store.canSave)
        store.discardChanges()
        #expect(store.draft.nickname == "Keep this")
        await store.save()
        let requests = await api.requests
        #expect(requests.count == 2)
        #expect(requests[1].idempotencyKey == pending.idempotencyKey)
        #expect(requests[1].body == pending.body)
        #expect(requests[1].expectedVersion == pending.expectedVersion)
        #expect(store.pending == nil)
        #expect(store.saved?.data.nickname == "Keep this")
    }

    @Test func conflictPreservesDraftAndRequiresExplicitRebaseAndNewSave() async throws {
        let original = record(TravelerProfile(nickname: "Original"))
        let remote = record(TravelerProfile(nickname: "Elsewhere"), version: 2)
        let api = ProfileStub(existing: original, failures: [try conflict(remote)])
        let store = ProfileStore(service: api)
        await store.load()
        store.draft.nickname = "My draft"
        await store.save()
        #expect(store.draft.nickname == "My draft")
        #expect(store.conflict?.saved?.data.nickname == "Elsewhere")
        #expect(!store.canSave && !store.canEdit)
        let firstKey = await api.requests.first?.idempotencyKey
        await store.save()
        #expect(await api.requests.count == 1)
        store.keepDraft()
        #expect(store.draft.nickname == "My draft")
        #expect(store.saved?.version == 2)
        #expect(await api.requests.count == 1)
        await store.save()
        #expect(await api.requests.last?.expectedVersion == 2)
        #expect(await api.requests.last?.idempotencyKey != firstKey)
    }

    @Test func acceptingServerCopyDoesNotWrite() async throws {
        let remote = record(TravelerProfile(homeBase: "New city"), version: 2)
        let api = ProfileStub(failures: [try conflict(remote)])
        let store = ProfileStore(service: api)
        await store.load()
        store.draft.homeBase = "Local city"
        await store.save()
        store.useSavedProfile()
        #expect(store.draft == remote.data)
        #expect(!store.dirty)
        #expect(await api.requests.count == 1)
    }

    @Test func validationRejectionKeepsEditableDraft() async {
        let api = ProfileStub(failures: [.rejected(status: 422, error: APIErrorBody(code: "validation_error", message: "Invalid request"), requestID: nil)])
        let store = ProfileStore(service: api)
        await store.load()
        store.draft.nickname = "Preserve"
        await store.save()
        #expect(store.draft.nickname == "Preserve")
        #expect(store.canEdit)
        #expect(store.pending == nil)
    }

    @Test func initialFailureCannotOverwriteAnUnloadedProfile() async {
        let store = ProfileStore(service: ProfileStub(loadFails: true))
        await store.load()
        #expect(!store.loaded)
        #expect(!store.canSave)
        #expect(store.errorMessage != nil)
    }

    @Test func localValidationDoesNotSendRequestOrLoseDraft() async {
        let api = ProfileStub()
        let store = ProfileStore(service: api)
        await store.load()
        store.draft.preferences.interests = Array(repeating: "Art", count: 31)
        await store.save()
        #expect(await api.requests.isEmpty)
        #expect(store.draft.preferences.interests.count == 31)
        #expect(store.canEdit)
        #expect(store.errorMessage != nil)
    }

    @Test func returningToEditorDoesNotReloadOverDraft() async {
        let api = ProfileStub(existing: record(TravelerProfile(nickname: "Saved")))
        let store = ProfileStore(service: api)
        await store.load()
        store.draft.nickname = "Unsaved"
        await store.load()
        #expect(store.draft.nickname == "Unsaved")
        #expect(await api.loads == 1)
        store.reset()
        #expect(!store.loaded)
        #expect(store.draft == TravelerProfile())
    }

    @Test func lateResponseCannotRestoreProfileAfterSignOut() async {
        let api = DelayedProfile()
        let store = ProfileStore(service: api)
        let loading = Task { await store.load() }
        while !(await api.started) { await Task.yield() }
        store.reset()
        await api.finish(record(TravelerProfile(nickname: "Previous account")))
        await loading.value
        #expect(!store.loaded)
        #expect(store.saved == nil)
        #expect(store.draft == TravelerProfile())
    }

    private func conflict(_ record: APIRecord<TravelerProfile>) throws -> APIClientError {
        let current = try APIJSON.decoder().decode(JSONValue.self, from: APIJSON.encoder().encode(record))
        return .conflict(APIErrorBody(code: "version_conflict", message: "Changed", details: .object(["current": current])), requestID: nil)
    }
}

private actor ProfileStub: ProfileServing {
    var existing: APIRecord<TravelerProfile>?
    var failures: [APIClientError]
    var requests: [APIRequest<APIRecord<TravelerProfile>>] = []
    var loads = 0
    let loadFails: Bool
    init(existing: APIRecord<TravelerProfile>? = nil, failures: [APIClientError] = [], loadFails: Bool = false) {
        self.existing = existing; self.failures = failures; self.loadFails = loadFails
    }
    func load() async throws -> APIRecord<TravelerProfile>? {
        loads += 1
        if loadFails { throw APIClientError.connection }
        return existing
    }
    func save(_ request: APIRequest<APIRecord<TravelerProfile>>) async throws -> APIRecord<TravelerProfile> {
        requests.append(request)
        if !failures.isEmpty { throw failures.removeFirst() }
        let body = try APIJSON.decoder().decode(TravelerProfile.self, from: request.body!)
        let record = APIRecord(id: "me", kind: "profile", version: request.expectedVersion! + 1, revision: 1, updatedAt: Date(), deleted: false, data: body)
        existing = record
        return record
    }
}

private actor DelayedProfile: ProfileServing {
    var continuation: CheckedContinuation<APIRecord<TravelerProfile>?, Never>?
    var started = false
    func load() async throws -> APIRecord<TravelerProfile>? {
        await withCheckedContinuation { continuation = $0; started = true }
    }
    func finish(_ record: APIRecord<TravelerProfile>) { continuation?.resume(returning: record); continuation = nil }
    func save(_ request: APIRequest<APIRecord<TravelerProfile>>) async throws -> APIRecord<TravelerProfile> { throw APIClientError.connection }
}
