import Foundation
import Testing
@testable import pipgogo

@MainActor
struct TripTests {
    @Test func createsListsAndReloadsTripWithCompanions() async throws {
        let api = TripStub()
        let store = TripStore(service: api)
        await store.load()
        #expect(store.loaded && store.items.isEmpty)
        store.beginCreation()
        let id = store.draftID
        let companion = UUID().uuidString.lowercased()
        store.draft = Trip(destinations: [" Japan ", "Kyoto"], startDate: "2026-11-01", endDate: "2026-11-10", accommodation: TripAccommodation(name: "Hotel", address: "Saved address", instructions: "Late arrival"), companionIDs: [companion])
        #expect(await store.save())
        #expect(!store.hasDraft && store.items.count == 1)
        #expect(store.items[0].id == id.uuidString.lowercased())
        let operation = try #require(await api.requests.first)
        #expect(operation.expectedVersion == 0 && operation.method == "PUT")
        let reopened = TripStore(service: api)
        await reopened.load()
        await reopened.refreshTrip(id.uuidString.lowercased())
        #expect(reopened.items == store.items)
        #expect(reopened.items.first?.data.destinations == ["Japan", "Kyoto"])
        #expect(reopened.items.first?.data.companionIDs == [companion])
    }

    @Test func optionalFieldsCanBeOmittedAndBlankAccommodationIsRemoved() async throws {
        let api = TripStub()
        let store = TripStore(service: api)
        store.beginCreation()
        store.draft.destinations = ["San Diego"]
        store.draft.accommodation = TripAccommodation(name: "  ", address: "")
        #expect(await store.save())
        let request = try #require(await api.requests.first)
        let json = try APIJSON.decoder().decode(JSONValue.self, from: #require(request.body))
        #expect(json["start_date"] == nil && json["end_date"] == nil && json["accommodation"] == nil)
        #expect(json["companion_ids"] == .array([]))
    }

    @Test func lostResponseRetriesExactRequestAndDoesNotDuplicateTrip() async throws {
        let api = TripStub(loseFirstResponse: true)
        let store = TripStore(service: api)
        store.beginCreation()
        store.draft.destinations = ["Japan"]
        #expect(await store.save() == false)
        let pending = try #require(store.pending)
        #expect(!store.canEdit && store.canSave && store.hasDraft)
        store.discardDraft()
        #expect(store.hasDraft)
        await store.load(refresh: true)
        #expect(store.items.count == 1) // The first request committed, but its response was lost.
        #expect(await store.save())
        let requests = await api.requests
        #expect(requests.count == 2)
        #expect(requests[1].endpoint == pending.endpoint)
        #expect(requests[1].idempotencyKey == pending.idempotencyKey)
        #expect(requests[1].body == pending.body && requests[1].expectedVersion == 0)
        #expect(store.items.count == 1 && !store.hasDraft)
        #expect(await api.records.count == 1)
    }

    @Test func navigationAndRefreshRetainTheSameDraft() async {
        let store = TripStore(service: TripStub())
        store.beginCreation()
        let id = store.draftID
        store.draft.destinations = ["Draft destination"]
        await store.load(refresh: true)
        store.beginCreation()
        #expect(store.draftID == id && store.draft.destinations == ["Draft destination"])
        store.discardDraft()
        store.beginCreation()
        #expect(store.draftID != id && store.draft == Trip())
    }

    @Test func validatesDestinationCountLengthsDatesAndCompanionLimits() async {
        let api = TripStub()
        let store = TripStore(service: api)
        store.beginCreation()
        let invalid = [
            Trip(destinations: []),
            Trip(destinations: Array(repeating: "City", count: 11)),
            Trip(destinations: [String(repeating: "a", count: 301)]),
            Trip(destinations: ["City"], startDate: "2026-02-30"),
            Trip(destinations: ["City"], startDate: "2026-11-10", endDate: "2026-11-01"),
            Trip(destinations: ["City"], companionIDs: ["not-a-uuid"]),
            Trip(destinations: ["City"], companionIDs: (0..<21).map { _ in UUID().uuidString }),
            Trip(destinations: ["City"], accommodation: TripAccommodation(instructions: String(repeating: "a", count: 2001)))
        ]
        for draft in invalid {
            store.draft = draft
            #expect(await store.save() == false)
            #expect(store.draft == draft && store.canEdit && store.saveError != nil)
        }
        #expect(await api.requests.isEmpty)
    }

    @Test func calendarDatesRemainDateOnlyAndLeapDaysAreValidated() throws {
        for day in ["2028-02-29", "2026-03-08", "2026-11-01"] {
            #expect(TripDates.string(try #require(TripDates.date(day))) == day)
        }
        #expect(TripDates.date("2026-02-29") == nil)
        #expect(TripDates.date("2026-9-1") == nil)
        let data = try APIJSON.encoder().encode(Trip(destinations: ["Tokyo"], startDate: "2026-11-01"))
        let json = try APIJSON.decoder().decode(JSONValue.self, from: data)
        #expect(json["start_date"] == .string("2026-11-01"))
    }

    @Test func fullBackendBodyRoundTripsWithoutDroppingUneditedFields() throws {
        let body = Trip(destinations: ["Tokyo", "Kyoto"], startDate: "2026-11-01", endDate: "2026-11-10",
                        accommodation: TripAccommodation(name: "Hotel", address: "Address", checkIn: "2026-11-02T15:00:00+09:00", instructions: "Check in late", reservationReference: "Reference"),
                        arrival: TripFlight(number: "AA1", airport: "HND", scheduledAt: "2026-11-02T12:30:00.123456+09:00"),
                        departure: TripFlight(number: "AA2", airport: "NRT", scheduledAt: "2026-11-10T10:00:00+09:00"),
                        companionIDs: [UUID().uuidString.lowercased()], preferences: TravelerPreferences(languages: ["English"], interests: ["Art"], dietaryNeeds: ["Vegetarian"], accessibilityNeeds: ["Step-free"], pace: "relaxed", budgetComfort: "premium", transportation: ["Train"]),
                        budgetMinor: 250000, currency: "USD", transportationPlan: "Train", itinerary: ["Museum", "Garden"], constraints: ["No stairs"])
        let encoded = try APIJSON.encoder().encode(body)
        let decoded = try APIJSON.decoder().decode(Trip.self, from: encoded)
        #expect(try decoded.validated() == body)
        #expect(try APIJSON.encoder().encode(decoded) == encoded)
        let json = try APIJSON.decoder().decode(JSONValue.self, from: encoded)
        #expect(json["accommodation"]?["reservation_reference"] == .string("Reference"))
        #expect(json["arrival"]?["scheduled_at"] == .string("2026-11-02T12:30:00.123456+09:00"))
        #expect(json["budget_minor"] == .integer(250000))
    }

    @Test func missingSelectedCompanionCanBeRemovedAfterDefiniteRejection() async {
        let failure = APIClientError.rejected(status: 404, error: APIErrorBody(code: "not_found", message: "Companion missing"), requestID: nil)
        let api = TripStub(failures: [failure])
        let store = TripStore(service: api)
        store.beginCreation()
        store.draft = Trip(destinations: ["Japan"], companionIDs: [UUID().uuidString.lowercased()])
        #expect(await store.save() == false)
        #expect(store.pending == nil && store.canEdit)
        #expect(store.saveError?.contains("companion") == true)
        store.draft.companionIDs = []
        #expect(await store.save())
        let requests = await api.requests
        #expect(requests.first?.idempotencyKey != requests.last?.idempotencyKey)
    }

    @Test func collisionNeverOverwritesExistingTripAndRequiresExplicitNewIdentity() async throws {
        let api = TripStub()
        let store = TripStore(service: api)
        store.beginCreation()
        let oldID = store.draftID
        let remote = record(id: oldID, title: "Existing trip")
        await api.failNext(try conflict(remote))
        store.draft.destinations = ["My draft"]
        #expect(await store.save() == false)
        #expect(store.conflict?.existing?.data.title == "Existing trip")
        #expect(!store.canEdit && !store.canSave)
        #expect(await store.save() == false)
        store.keepAsNewTrip()
        #expect(store.draftID != oldID && store.draft.title == "My draft")
        #expect(await api.requests.count == 1)
        #expect(await store.save())
        #expect(await api.requests.last?.expectedVersion == 0)
        #expect(store.items.count == 2)
    }

    @Test func acceptingExistingTripDoesNotSendAnotherWrite() async throws {
        let api = TripStub()
        let store = TripStore(service: api)
        store.beginCreation()
        await api.failNext(try conflict(record(id: store.draftID)))
        store.draft.destinations = ["Draft"]
        await store.save()
        store.useExistingTrip()
        #expect(!store.hasDraft && store.items.count == 1)
        #expect(await api.requests.count == 1)
    }

    @Test func deletedTripDisappearsOnDetailRefresh() async {
        let saved = record()
        let api = TripStub(records: [saved])
        let store = TripStore(service: api)
        await store.load()
        await api.removeRecords()
        await store.refreshTrip(saved.id)
        #expect(store.items.isEmpty && store.errorMessage != nil)
    }

    @Test func listFailureKeepsPreviousTripsAndAllowsRetry() async {
        let api = TripStub(records: [record()])
        let store = TripStore(service: api)
        await store.load()
        await api.setListFailure(true)
        await store.load(refresh: true)
        #expect(store.loaded && store.items.count == 1 && store.errorMessage != nil)
        await api.setListFailure(false)
        await store.load(refresh: true)
        #expect(store.errorMessage == nil)
    }

    @Test func lateSaveCannotRestoreTripsAfterSignOut() async {
        let api = DelayedTrip()
        let store = TripStore(service: api)
        store.beginCreation()
        store.draft.destinations = ["Previous account"]
        let saving = Task { await store.save() }
        while !(await api.started) { await Task.yield() }
        store.reset()
        await api.finish()
        #expect(await saving.value == false)
        #expect(store.items.isEmpty && !store.hasDraft && store.pending == nil && !store.loaded)
    }

    @Test func replayedReceiptCannotReplaceNewerFetchedTrip() async throws {
        let api = TripStub(loseFirstResponse: true)
        let store = TripStore(service: api)
        store.beginCreation()
        store.draft.destinations = ["Original"]
        await store.save()
        let newer = APIRecord(id: store.draftID.uuidString.lowercased(), kind: "trip", version: 2, revision: 2, updatedAt: Date(), deleted: false, data: Trip(destinations: ["Newer edit"]))
        await api.replaceRecords([newer])
        await store.load(refresh: true)
        #expect(await store.save())
        #expect(store.items.first?.version == 2 && store.items.first?.data.title == "Newer edit")
    }

    @Test func lateListCannotRestorePreviousAccountTrips() async {
        let api = DelayedTripList()
        let store = TripStore(service: api)
        let loading = Task { await store.load() }
        while !(await api.started) { await Task.yield() }
        store.reset()
        await api.finish([record()])
        await loading.value
        #expect(store.items.isEmpty && !store.loaded)
    }

    @Test func editingSendsSavedVersionAndPreservesUnexposedFields() async throws {
        let original = APIRecord(id: UUID().uuidString.lowercased(), kind: "trip", version: 4, revision: 8, updatedAt: Date(), deleted: false,
            data: Trip(destinations: ["Tokyo"], accommodation: TripAccommodation(name: "Hotel", checkIn: "2026-11-01T15:00:00+09:00", reservationReference: "ABC"), arrival: TripFlight(number: "AA1", airport: "HND", scheduledAt: "2026-11-01T12:00:00+09:00"), budgetMinor: 123456, currency: "USD", itinerary: ["Museum"]))
        let api = TripStub(records: [original])
        let store = TripStore(service: api)
        await store.load()
        #expect(store.beginEditing(original.id))
        #expect(!store.canSave && store.canDelete)
        store.draft.destinations = ["Tokyo", "Kyoto"]
        store.draft.accommodation?.name = nil
        #expect(!store.canDelete)
        #expect(await store.save())
        let request = try #require(await api.requests.last)
        #expect(request.expectedVersion == 4)
        let body = try APIJSON.decoder().decode(Trip.self, from: #require(request.body))
        #expect(body.arrival == original.data.arrival && body.budgetMinor == 123456 && body.currency == "USD")
        #expect(body.accommodation?.checkIn == original.data.accommodation?.checkIn)
        #expect(body.accommodation?.reservationReference == "ABC" && body.accommodation?.name == nil)
        await store.refreshTrip(original.id)
        #expect(store.items.first?.data == body)
    }

    @Test func editDraftSurvivesNavigationAndListRefresh() async {
        let original = record(), other = record()
        let store = TripStore(service: TripStub(records: [original, other]))
        await store.load()
        store.beginEditing(original.id)
        store.draft.destinations = ["Unsaved"]
        await store.load(refresh: true)
        #expect(!store.beginEditing(other.id))
        #expect(store.beginEditing(original.id))
        #expect(store.draft.destinations == ["Unsaved"])
        store.discardDraft()
        #expect(!store.hasDraft && store.items.first?.data == original.data)
    }

    @Test func failedEditRetainsBodyKeyAndExpectedVersion() async throws {
        let original = record()
        let api = TripStub(records: [original], failures: [.connection])
        let store = TripStore(service: api)
        await store.load(); store.beginEditing(original.id)
        store.draft.destinations = ["Kyoto"]
        #expect(await store.save() == false)
        let pending = try #require(store.pending)
        #expect(!store.canDelete && !store.canEdit)
        #expect(await store.save())
        let retry = try #require(await api.requests.last)
        #expect(retry.idempotencyKey == pending.idempotencyKey && retry.body == pending.body && retry.expectedVersion == 1)
    }

    @Test func editConflictRequiresReviewAndSeparateSaveWithNewVersionAndKey() async throws {
        let original = record()
        let remote = APIRecord(id: original.id, kind: "trip", version: 2, revision: 2, updatedAt: original.updatedAt, deleted: false, data: Trip(destinations: ["Remote"] ))
        let api = TripStub(records: [original], failures: [try conflict(remote)])
        let store = TripStore(service: api)
        await store.load(); store.beginEditing(original.id)
        store.draft.destinations = ["My draft"]
        await store.save()
        #expect(store.draft.title == "My draft" && store.conflict?.existing == remote)
        #expect(!store.canSave && !store.canDelete)
        store.keepDraft()
        #expect(await api.requests.count == 1)
        #expect(store.base?.version == 2 && store.draft.title == "My draft")
        #expect(await store.save())
        let requests = await api.requests
        #expect(requests.last?.expectedVersion == 2 && requests.first?.idempotencyKey != requests.last?.idempotencyKey)
    }

    @Test func acceptsRemoteEditWithoutWriting() async throws {
        let original = record()
        let remote = APIRecord(id: original.id, kind: "trip", version: 2, revision: 2, updatedAt: original.updatedAt, deleted: false, data: Trip(destinations: ["Remote"]))
        let api = TripStub(records: [original], failures: [try conflict(remote)])
        let store = TripStore(service: api)
        await store.load(); store.beginEditing(original.id)
        store.draft.destinations = ["Local"]
        await store.save()
        store.useExistingTrip()
        #expect(!store.hasDraft && store.items.first == remote)
        #expect(await api.requests.count == 1)
    }

    @Test func uncertainDeleteReplaysSameIntentAndRemovesTheTrip() async throws {
        let original = record()
        let api = TripStub(records: [original])
        await api.loseNextDeletionResponse()
        let store = TripStore(service: api)
        await store.load(); store.beginEditing(original.id)
        #expect(await store.delete() == false)
        let pending = try #require(store.pendingDeletion)
        #expect(store.hasDraft && !store.canEdit && !store.canSave)
        store.discardDraft()
        #expect(store.hasDraft)
        #expect(await store.delete())
        let retry = try #require(await api.deletions.last)
        #expect(retry.idempotencyKey == pending.idempotencyKey && retry.expectedVersion == 1 && retry.body == nil)
        #expect(store.items.isEmpty && !store.hasDraft)
        await store.load(refresh: true)
        #expect(store.items.isEmpty)
    }

    @Test func deletionConflictRequiresReviewAndNewConfirmation() async throws {
        let original = record()
        let remote = APIRecord(id: original.id, kind: "trip", version: 2, revision: 2, updatedAt: original.updatedAt, deleted: false, data: Trip(destinations: ["New destination"]))
        let api = TripStub(records: [original], failures: [try conflict(remote)])
        let store = TripStore(service: api)
        await store.load(); store.beginEditing(original.id)
        #expect(await store.delete() == false)
        #expect(await store.delete() == false)
        #expect(await api.deletions.count == 1)
        store.useExistingTrip()
        #expect(store.items.first?.data.title == "New destination")
        store.beginEditing(original.id)
        #expect(await store.delete())
        let calls = await api.deletions
        #expect(calls.last?.expectedVersion == 2 && calls.first?.idempotencyKey != calls.last?.idempotencyKey)
    }

    @Test func remoteDeletionCanOnlyBeCopiedToANewIdentity() async throws {
        let original = record()
        let tombstone = APIRecord(id: original.id, kind: "trip", version: 2, revision: 2, updatedAt: original.updatedAt, deleted: true, data: JSONValue.object([:]))
        let value = try APIJSON.decoder().decode(JSONValue.self, from: APIJSON.encoder().encode(tombstone))
        let failure = APIClientError.conflict(APIErrorBody(code: "version_conflict", message: "Removed", details: .object(["current": value])), requestID: nil)
        let api = TripStub(records: [original], failures: [failure])
        let store = TripStore(service: api)
        await store.load(); store.beginEditing(original.id)
        store.draft.destinations = ["Retained draft"]
        await store.save()
        store.keepDraft()
        #expect(store.conflict != nil && !store.canSave)
        store.keepAsNewTrip()
        #expect(store.draftID.uuidString.lowercased() != original.id && store.draft.title == "Retained draft")
        #expect(store.items.isEmpty && !store.isEditing)
        #expect(await store.save())
        #expect(await api.requests.last?.expectedVersion == 0)
    }

    @Test func knownDeletionPreventsOlderReceiptFromResurrectingListRow() async {
        let original = record()
        let api = TripStub(records: [original], loseFirstResponse: true)
        let store = TripStore(service: api)
        await store.load(); store.beginEditing(original.id)
        store.draft.destinations = ["Changed"]
        await store.save()
        await api.removeRecords()
        await store.load(refresh: true)
        #expect(store.items.isEmpty)
        #expect(await store.save())
        #expect(store.items.isEmpty)
    }

    @Test func invalidOptionalListsKeepDraftEditableWithoutWriting() async {
        let api = TripStub(records: [record()])
        let store = TripStore(service: api)
        await store.load(); store.beginEditing(store.items[0].id)
        store.draft.itinerary = Array(repeating: "Stop", count: 51)
        #expect(await store.save() == false)
        #expect(store.canEdit && store.pending == nil && store.draft.itinerary.count == 51)
        #expect(await api.requests.isEmpty)
    }

    @Test func lateDeletionCannotChangeNewAccountState() async {
        let original = record()
        let api = DelayedTripDeletion(record: original)
        let store = TripStore(service: api)
        await store.load(); store.beginEditing(original.id)
        let deleting = Task { await store.delete() }
        while !(await api.started) { await Task.yield() }
        store.reset()
        await api.finish()
        #expect(await deleting.value == false)
        #expect(store.items.isEmpty && !store.hasDraft && store.pendingDeletion == nil)
    }

    private func record(id: UUID = UUID(), title: String = "Tokyo") -> APIRecord<Trip> {
        APIRecord(id: id.uuidString.lowercased(), kind: "trip", version: 1, revision: 1, updatedAt: Date(timeIntervalSince1970: 1_800_000_000), deleted: false, data: Trip(destinations: [title]))
    }
    private func conflict(_ record: APIRecord<Trip>) throws -> APIClientError {
        let current = try APIJSON.decoder().decode(JSONValue.self, from: APIJSON.encoder().encode(record))
        return .conflict(APIErrorBody(code: "version_conflict", message: "Changed", details: .object(["current": current])), requestID: nil)
    }
}

private actor TripStub: TripServing {
    var records: [APIRecord<Trip>]
    var requests: [APIRequest<APIRecord<Trip>>] = []
    var deletions: [APIRequest<APIRecord<JSONValue>>] = []
    var deletionReceipts: [UUID: APIRecord<JSONValue>] = [:]
    var loseDeletionResponse = false
    var failures: [APIClientError]
    var receipts: [UUID: APIRecord<Trip>] = [:]
    var loseFirstResponse: Bool
    var listFails = false
    init(records: [APIRecord<Trip>] = [], failures: [APIClientError] = [], loseFirstResponse: Bool = false) {
        self.records = records; self.failures = failures; self.loseFirstResponse = loseFirstResponse
    }
    func loseNextDeletionResponse() { loseDeletionResponse = true }
    func loseNextSaveResponse() { loseFirstResponse = true }
    func failNext(_ failure: APIClientError) { failures.append(failure) }
    func removeRecords() { records = [] }
    func replaceRecords(_ records: [APIRecord<Trip>]) { self.records = records }
    func setListFailure(_ fail: Bool) { listFails = fail }
    func list() async throws -> [APIRecord<Trip>] {
        if listFails { throw APIClientError.connection }
        return records
    }
    func load(_ id: UUID) async throws -> APIRecord<Trip> {
        guard let record = records.first(where: { $0.id == id.uuidString.lowercased() }) else {
            throw APIClientError.rejected(status: 404, error: APIErrorBody(code: "not_found", message: "Missing"), requestID: nil)
        }
        return record
    }
    func save(_ request: APIRequest<APIRecord<Trip>>) async throws -> APIRecord<Trip> {
        requests.append(request)
        if !failures.isEmpty { throw failures.removeFirst() }
        if let key = request.idempotencyKey, let receipt = receipts[key] { return receipt }
        guard case .trip(let id) = request.endpoint else { throw APIClientError.invalidResponse }
        let body = try APIJSON.decoder().decode(Trip.self, from: request.body!)
        let record = APIRecord(id: id.uuidString.lowercased(), kind: "trip", version: (request.expectedVersion ?? 0) + 1, revision: (records.map(\.revision).max() ?? 0) + 1, updatedAt: Date(), deleted: false, data: body)
        records.removeAll { $0.id == record.id }
        records.append(record)
        receipts[request.idempotencyKey!] = record
        if loseFirstResponse { loseFirstResponse = false; throw APIClientError.connection }
        return record
    }
    func delete(_ request: APIRequest<APIRecord<JSONValue>>) async throws -> APIRecord<JSONValue> {
        deletions.append(request)
        if !failures.isEmpty { throw failures.removeFirst() }
        if let key = request.idempotencyKey, let receipt = deletionReceipts[key] { return receipt }
        guard case .trip(let id) = request.endpoint else { throw APIClientError.invalidResponse }
        let record = APIRecord(id: id.uuidString.lowercased(), kind: "trip", version: request.expectedVersion! + 1, revision: request.expectedVersion! + 1, updatedAt: Date(), deleted: true, data: JSONValue.object([:]))
        records.removeAll { $0.id == record.id }
        deletionReceipts[request.idempotencyKey!] = record
        if loseDeletionResponse { loseDeletionResponse = false; throw APIClientError.connection }
        return record
    }

}

private actor DelayedTrip: TripServing {
    func delete(_ request: APIRequest<APIRecord<JSONValue>>) async throws -> APIRecord<JSONValue> { throw APIClientError.connection }
    var continuation: CheckedContinuation<APIRecord<Trip>, Never>?
    var request: APIRequest<APIRecord<Trip>>?
    var started = false
    func list() async throws -> [APIRecord<Trip>] { [] }
    func load(_ id: UUID) async throws -> APIRecord<Trip> { throw APIClientError.connection }
    func save(_ request: APIRequest<APIRecord<Trip>>) async throws -> APIRecord<Trip> {
        self.request = request
        return await withCheckedContinuation { continuation = $0; started = true }
    }
    func finish() {
        guard let request, case .trip(let id) = request.endpoint else { return }
        let body = try! APIJSON.decoder().decode(Trip.self, from: request.body!)
        continuation?.resume(returning: APIRecord(id: id.uuidString.lowercased(), kind: "trip", version: 1, revision: 1, updatedAt: .now, deleted: false, data: body))
        continuation = nil
    }
}

private actor DelayedTripList: TripServing {
    func delete(_ request: APIRequest<APIRecord<JSONValue>>) async throws -> APIRecord<JSONValue> { throw APIClientError.connection }
    var continuation: CheckedContinuation<[APIRecord<Trip>], Never>?
    var started = false
    func list() async throws -> [APIRecord<Trip>] {
        await withCheckedContinuation { continuation = $0; started = true }
    }
    func finish(_ records: [APIRecord<Trip>]) { continuation?.resume(returning: records); continuation = nil }
    func load(_ id: UUID) async throws -> APIRecord<Trip> { throw APIClientError.connection }
    func save(_ request: APIRequest<APIRecord<Trip>>) async throws -> APIRecord<Trip> { throw APIClientError.connection }
}

private actor DelayedTripDeletion: TripServing {
    let record: APIRecord<Trip>
    var continuation: CheckedContinuation<APIRecord<JSONValue>, Never>?
    var started = false
    init(record: APIRecord<Trip>) { self.record = record }
    func list() async throws -> [APIRecord<Trip>] { [record] }
    func load(_ id: UUID) async throws -> APIRecord<Trip> { record }
    func save(_ request: APIRequest<APIRecord<Trip>>) async throws -> APIRecord<Trip> { throw APIClientError.connection }
    func delete(_ request: APIRequest<APIRecord<JSONValue>>) async throws -> APIRecord<JSONValue> {
        await withCheckedContinuation { continuation = $0; started = true }
    }
    func finish() {
        continuation?.resume(returning: APIRecord(id: record.id, kind: "trip", version: 2, revision: 2, updatedAt: .now, deleted: true, data: .object([:])))
        continuation = nil
    }
}
