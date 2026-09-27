import Foundation
import Testing
@testable import pipgogo

private let checkInID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
private func context(_ version: Int = 1, saved: APIRecord<TripCheckIn>? = nil) -> CheckInContext {
    CheckInContext(trip: APIRecord(id: checkInID.uuidString.lowercased(), kind: "trip", version: version, revision: version, updatedAt: Date(), deleted: false, data: Trip(destinations: ["Japan"])), checkIn: saved)
}
private func record(_ tripVersion: Int = 1, version: Int = 1, requests: String? = "Window seat", concerns: String? = nil) -> APIRecord<TripCheckIn> {
    APIRecord(id: checkInID.uuidString.lowercased(), kind: "checkin", version: version, revision: version + 1, updatedAt: Date(), deleted: false,
              data: TripCheckIn(confirmedTripVersion: tripVersion, requests: requests, concerns: concerns, needsReconfirmed: false, tripID: checkInID.uuidString.lowercased(), refresh: CheckInRefresh(status: "unavailable", attemptedAt: Date(), missingCategories: ["weather"], warnings: ["Not verified"], observations: [])))
}
private actor CheckInStub: CheckInServing {
    var current = context()
    var failure: APIClientError?
    var loadFailure = false
    var requests: [APIRequest<APIRecord<TripCheckIn>>] = []
    var response = record()
    var delayLoad = false
    var delaySave = false
    var started = false
    var continuation: CheckedContinuation<Void, Never>?
    func configure(current: CheckInContext? = nil, failure: APIClientError? = nil, loadFailure: Bool = false, response: APIRecord<TripCheckIn>? = nil, delayLoad: Bool = false, delaySave: Bool = false) {
        if let current { self.current = current }
        self.failure = failure; self.loadFailure = loadFailure
        if let response { self.response = response }
        self.delayLoad = delayLoad; self.delaySave = delaySave
    }
    func load(_ id: UUID) async throws -> CheckInContext {
        if delayLoad { started = true; await withCheckedContinuation { continuation = $0 } }
        if loadFailure { throw APIClientError.connection }
        return current
    }
    func save(_ request: APIRequest<APIRecord<TripCheckIn>>) async throws -> APIRecord<TripCheckIn> {
        requests.append(request)
        if delaySave { started = true; await withCheckedContinuation { continuation = $0 } }
        if let failure { throw failure }
        return response
    }
    func release() { continuation?.resume(); continuation = nil }
}

@MainActor struct CheckInTests {
    @Test func firstCheckInRequiresLoadedContextAndExplicitConfirmation() async throws {
        let service = CheckInStub(); let store = CheckInStore(id: checkInID, service: service)
        store.confirmed = true; #expect(!store.canSave)
        await store.load(); #expect(store.loaded); #expect(!store.canSave)
        store.requests = "Window seat"; store.confirmed = true
        await service.configure(current: context(saved: record()))
        await store.save()
        let request = try #require(await service.requests.first)
        #expect(request.expectedVersion == 0)
        #expect(request.endpoint == .checkIn(checkInID))
        let body = try APIJSON.decoder().decode(CheckInInput.self, from: #require(request.body))
        #expect(body.confirmedTripVersion == 1); #expect(!body.needsReconfirmed)
        #expect(store.isCurrent); #expect(!store.confirmed)
    }
    @Test func reopenAndClearOptionalNotes() async throws {
        let service = CheckInStub(); await service.configure(current: context(saved: record()))
        let store = CheckInStore(id: checkInID, service: service); await store.load()
        #expect(store.requests == "Window seat")
        store.requests = "  "; store.concerns = ""; store.confirmed = true
        await store.save()
        let request = try #require(await service.requests.first)
        #expect(request.expectedVersion == 1)
        let body = try APIJSON.decoder().decode(CheckInInput.self, from: #require(request.body))
        #expect(body.requests == nil); #expect(body.concerns == nil)
    }
    @Test func uncertainSaveFreezesAndRetriesIdenticalRequest() async throws {
        let service = CheckInStub(); await service.configure(failure: .connection)
        let store = CheckInStore(id: checkInID, service: service); await store.load()
        store.requests = "Please help"; store.confirmed = true; await store.save()
        #expect(store.pending != nil); #expect(!store.canEdit)
        await store.load(); #expect(store.requests == "Please help"); #expect(store.canSave)
        await store.save()
        let requests = await service.requests
        #expect(requests.count == 2); #expect(requests[0].body == requests[1].body)
        #expect(requests[0].idempotencyKey == requests[1].idempotencyKey)
        #expect(requests[0].expectedVersion == requests[1].expectedVersion)
    }
    @Test func tripChangedRequiresRefreshAndReconfirmation() async throws {
        let service = CheckInStub(); let store = CheckInStore(id: checkInID, service: service)
        await store.load(); store.requests = "Keep these notes"; store.confirmed = true
        await service.configure(failure: .conflict(APIErrorBody(code: "trip_changed", message: "Changed"), requestID: nil))
        await store.save(); #expect(store.pending == nil); #expect(!store.loaded); #expect(!store.canSave)
        await service.configure(current: context(2)); await store.load()
        #expect(store.requests == "Keep these notes"); #expect(!store.confirmed)
        store.confirmed = true; await store.save()
        let requests = await service.requests
        let body = try APIJSON.decoder().decode(CheckInInput.self, from: #require(requests.last?.body))
        #expect(body.confirmedTripVersion == 2); #expect(requests[0].idempotencyKey != requests[1].idempotencyKey)
    }
    @Test func conflictingNotesRequireDeliberateRebaseAndNewSave() async throws {
        let service = CheckInStub(); let store = CheckInStore(id: checkInID, service: service)
        await store.load(); store.requests = "My notes"; store.confirmed = true
        let existing = record(version: 2, requests: "Remote notes")
        let json = try APIJSON.decoder().decode(JSONValue.self, from: APIJSON.encoder().encode(existing))
        await service.configure(current: context(saved: existing), failure: .conflict(APIErrorBody(code: "version_conflict", message: "Changed", details: .object(["current": json])), requestID: nil))
        await store.save(); #expect(store.hasConflict); #expect(store.requests == "My notes"); #expect(!store.canSave)
        await service.configure()
        await store.resolveConflict(useSaved: false)
        #expect(store.requests == "My notes"); #expect(!store.confirmed)
        #expect(await service.requests.count == 1)
        store.confirmed = true; await store.save()
        let requests = await service.requests
        #expect(requests.last?.expectedVersion == 2); #expect(requests[0].idempotencyKey != requests[1].idempotencyKey)
    }
    @Test func refreshPreservesDraftAndInvalidatesConfirmation() async {
        let service = CheckInStub(); let store = CheckInStore(id: checkInID, service: service)
        await store.load(); store.concerns = "Walking"; store.confirmed = true
        await service.configure(current: context(2)); await store.load()
        #expect(store.concerns == "Walking"); #expect(!store.confirmed); #expect(store.trip?.version == 2)
    }
    @Test func loadFailureBlocksSaveAndPreservesNotes() async {
        let service = CheckInStub(); let store = CheckInStore(id: checkInID, service: service)
        await store.load(); store.requests = "Keep"; store.confirmed = true
        await service.configure(loadFailure: true); await store.load()
        #expect(!store.canSave); #expect(store.requests == "Keep"); #expect(!store.loaded)
    }
    @Test func oldReceiptCannotConfirmNewerTrip() async {
        let service = CheckInStub(); let store = CheckInStore(id: checkInID, service: service)
        await store.load(); store.confirmed = true
        await service.configure(current: context(2, saved: record()), response: record())
        await store.save(); #expect(!store.isCurrent); #expect(store.trip?.version == 2)
    }
    @Test func successfulSaveWithFailedRefreshDoesNotClaimCurrent() async {
        let service = CheckInStub(); let store = CheckInStore(id: checkInID, service: service)
        await store.load(); store.confirmed = true
        await service.configure(loadFailure: true); await store.save()
        #expect(store.saved != nil); #expect(store.pending == nil); #expect(!store.isCurrent)
    }
    @Test func validationUsesUnicodeScalarLimitAndDoesNotSend() async {
        let service = CheckInStub(); let store = CheckInStore(id: checkInID, service: service)
        await store.load(); store.requests = String(repeating: "e\u{301}", count: 1001); store.confirmed = true
        await store.save(); #expect(await service.requests.isEmpty); #expect(store.pending == nil)
    }
    @Test func resetIgnoresLateLoad() async {
        let service = CheckInStub(); await service.configure(delayLoad: true)
        let store = CheckInStore(id: checkInID, service: service)
        let task = Task { await store.load() }
        while !(await service.started) { await Task.yield() }
        store.reset(); await service.release(); await task.value
        #expect(!store.loaded); #expect(store.trip == nil); #expect(store.requests.isEmpty)
    }
    @Test func resetIgnoresLateSave() async {
        let service = CheckInStub(); let store = CheckInStore(id: checkInID, service: service)
        await store.load(); store.confirmed = true; await service.configure(delaySave: true)
        let task = Task { await store.save() }
        while !(await service.started) { await Task.yield() }
        store.reset(); await service.release(); await task.value
        #expect(store.saved == nil); #expect(store.pending == nil); #expect(!store.loaded)
    }
    @Test func useSavedNotesIsExplicitAndDoesNotWrite() async throws {
        let service = CheckInStub(); let store = CheckInStore(id: checkInID, service: service)
        await store.load(); store.requests = "Local"; store.confirmed = true
        let existing = record(version: 2, requests: "Remote")
        let json = try APIJSON.decoder().decode(JSONValue.self, from: APIJSON.encoder().encode(existing))
        await service.configure(current: context(saved: existing), failure: .conflict(APIErrorBody(code: "version_conflict", message: "Changed", details: .object(["current": json])), requestID: nil))
        await store.save(); await store.resolveConflict(useSaved: true)
        #expect(store.requests == "Remote"); #expect(!store.confirmed); #expect(await service.requests.count == 1)
    }
    @Test func malformedConflictRetainsFrozenRequest() async {
        let service = CheckInStub(); let store = CheckInStore(id: checkInID, service: service)
        await store.load(); store.confirmed = true
        await service.configure(failure: .conflict(APIErrorBody(code: "version_conflict", message: "Changed"), requestID: nil))
        await store.save(); #expect(store.pending != nil); #expect(!store.hasConflict); #expect(!store.canEdit)
    }
    @Test func deletedParentBlocksFurtherConfirmation() async {
        let service = CheckInStub(); let store = CheckInStore(id: checkInID, service: service)
        await store.load(); store.concerns = "Keep"; store.confirmed = true
        await service.configure(failure: .rejected(status: 404, error: APIErrorBody(code: "not_found", message: "Missing"), requestID: nil))
        await store.save(); #expect(!store.loaded); #expect(!store.canSave); #expect(store.concerns == "Keep")
    }
    @Test func collectionRetainsPerTripDraftsAndClearsOnSignOut() {
        let collection = CheckInCollection(service: CheckInStub())
        let first = collection.store(for: checkInID); first.requests = "Private"
        let other = collection.store(for: UUID()); other.requests = "Other"
        #expect(collection.store(for: checkInID) === first)
        collection.reset(); #expect(first.requests.isEmpty); #expect(other.requests.isEmpty)
        #expect(collection.store(for: checkInID) !== first)
    }
}
