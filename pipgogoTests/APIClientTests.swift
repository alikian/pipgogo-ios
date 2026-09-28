import Foundation
import Testing
@testable import pipgogo

@Suite(.serialized)
struct APIClientTests {
    @Test func doorToDoorRoundTripAndExternalSearch() throws {
        var intake = TripIntake(); intake.destination = "New York"; intake.start_date = "2026-10-10"; intake.end_date = "2026-10-14"
        var travel = DoorToDoorTravel(); travel.mode = "fly"; travel.departure_airport = "SAN"
        var flight = FlightSegment(); flight.arrival_airport = "EWR"; flight.departure_airport = "SAN"
        flight.departure_timezone = "America/Los_Angeles"; flight.arrival_timezone = "America/New_York"
        flight.departure_local = "2026-10-10T23:00"; flight.arrival_local = "2026-10-11T07:00"
        travel.flights = [flight]; travel.transfers = [GroundTransfer(leg: "airport_to_hotel")]; intake.door_to_door = travel
        let decoded = try APIJSON.decoder().decode(TripIntake.self, from: APIJSON.encoder().encode(intake))
        #expect(decoded == intake)
        let url = travel.flightSearchURL(destination: intake.destination, when: "", start: intake.start_date, end: intake.end_date)
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first?.value ?? ""
        #expect(url.host == "www.google.com")
        #expect(query.contains("SAN") && query.contains("New York") && query.contains("2026-10-14"))
    }

    @Test func olderJourneyIntakeDecodesWithoutDoorToDoorFields() throws {
        var intake = TripIntake(); intake.destination = "San Diego"
        let encoded = try APIJSON.encoder().encode(intake)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "door_to_door")
        let decoded = try APIJSON.decoder().decode(TripIntake.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.door_to_door == nil)
        #expect(decoded.destination == "San Diego")
    }

    @MainActor @Test func preferredNameRequiresExplicitPersistentMemory() {
        let store = IntelligenceStore(client: APIClient(baseURL: URL(string: "https://example.invalid")!), authentication: TestTokens())
        var memory = TravelerMemory(); memory.key = "preferred_name"; memory.value = "Sara"; memory.status = "inferred"
        func record(_ value: TravelerMemory) -> APIRecord<TravelerMemory> {
            APIRecord(id: UUID().uuidString.lowercased(), kind: "memory", version: 1, revision: 1, updatedAt: Date(), deleted: false, data: value)
        }
        store.memories = [record(memory)]; #expect(store.preferredName == nil)
        memory.status = "confirmed"; store.memories = [record(memory)]; #expect(store.preferredName == "Sara")
        memory.scope = "trip_specific"; store.memories = [record(memory)]; #expect(store.preferredName == nil)
        store.selectedID = UUID(); store.newTrip(language: "en"); #expect(store.selectedID == nil)
    }

    @Test func savedConversationAndPlanChangesSurviveReload() throws {
        let progress = try APIJSON.decoder().decode(IntakeProgress.self, from: Data(#"{"next_step":"lodging","question":"Where are you staying?","turns":2,"skipped":["flights"],"answers":{"travel_mode":{"text":"train"}}}"#.utf8))
        #expect(progress.next_step == "lodging")
        #expect(progress.skipped == ["flights"])
        let changes = PlanChanges(unchanged: ["Hotel"], added: ["Market"], changed: [], removed: ["Long walk"])
        #expect(try APIJSON.decoder().decode(PlanChanges.self, from: APIJSON.encoder().encode(changes)) == changes)
        let request = try APIRequest<Journey>.put(.journeyAction(UUID()), body: PipAction(action: "skip_intake", skip_topic: "lodging"), expectedVersion: 3)
        let body = try APIJSON.decoder().decode(JSONValue.self, from: request.body!)
        #expect(body["skip_topic"] == .string("lodging"))
    }

    @MainActor @Test func importReviewRejectionDoesNotFreezeActions() async throws {
        let id = UUID()
        var intake = TripIntake(); intake.destination = "New York"
        let record = APIRecord(id: id.uuidString.lowercased(), kind: "journey", version: 1, revision: 1, updatedAt: Date(), deleted: false,
            data: Journey(intake: intake, messages: [], plan: [], proposal: nil, imports: [], onboarding_done: false, temporary_context: ""))
        let error = Data(#"{"error":{"code":"import_review_required","message":"Review the import first"}}"#.utf8)
        let store = IntelligenceStore(client: APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: queuedSession([.init(status: 409, body: error)])), authentication: TestTokens())
        store.journeys = [record]; store.selectedID = id; store.edit(record)
        await store.act(PipAction(action: "plan"))
        #expect(!store.hasPending)
        #expect(store.error == "Review the import first")
        #expect(store.selected?.data.intake.destination == "New York")
    }

    @MainActor @Test func preferredNameAloneDoesNotSkipTravelerIntroduction() {
        let store = IntelligenceStore(client: APIClient(baseURL: URL(string: "https://example.invalid")!), authentication: TestTokens())
        var memory = TravelerMemory(); memory.key = "preferred_name"; memory.value = "Sara"
        store.memories = [APIRecord(id: UUID().uuidString, kind: "memory", version: 1, revision: 1, updatedAt: Date(), deleted: false, data: memory)]
        #expect(store.needsIntroduction)
        store.introduction = APIRecord(id: "me", kind: "introduction", version: 1, revision: 1, updatedAt: Date(), deleted: false, data: TravelerIntroduction(messages: [], onboarding_done: true))
        #expect(!store.needsIntroduction)
        store.reset()
        #expect(store.needsIntroduction)
        #expect(store.introduction == nil)
    }

    @MainActor @Test func introductionTimeoutKeepsAnswerAndRequestForExactRetry() async throws {
        let intro = APIRecord(id: "me", kind: "introduction", version: 1, revision: 1, updatedAt: Date(), deleted: false, data: TravelerIntroduction(messages: [], onboarding_done: false))
        let body = try APIJSON.encoder().encode(intro)
        let client = APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: queuedSession([.init(error: .timedOut), .init(status: 200, body: body), .init(status: 200, body: body), .init(status: 200, body: Data(#"{"items":[]}"#.utf8))]))
        let store = IntelligenceStore(client: client, authentication: TestTokens())
        store.introduction = APIRecord(id: "me", kind: "introduction", version: 0, revision: 0, updatedAt: Date(), deleted: false, data: intro.data)
        store.introductionAnswer = "Wandering in Italy"
        await store.introduce(language: "en")
        #expect(store.hasPending)
        #expect(store.introductionAnswer == "Wandering in Italy")
        let frozen = store.pendingIntroduction?.body
        await store.retryIntroduction()
        #expect(!store.hasPending)
        #expect(StubURLProtocol.bodies[0] == frozen)
        #expect(StubURLProtocol.bodies[1] == frozen)
        #expect(store.journeys.isEmpty)
    }

    @Test func mapsUnauthorizedResponse() async {
        let client = APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: makeSession(status: 401, body: Data()))
        await #expect(throws: APIClientError.unauthorized) { try await client.account(accessToken: "not-a-real-token") }
    }

    @Test func surfacesBackendErrorMessage() async {
        let body = Data(#"{"error":{"code":"identity_unavailable","message":"Identity provider is unavailable"}}"#.utf8)
        let client = APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: makeSession(status: 503, body: body))
        await #expect(throws: APIClientError.rejected(status: 503, error: APIErrorBody(code: "identity_unavailable", message: "Identity provider is unavailable"), requestID: nil)) {
            try await client.account(accessToken: "not-a-real-token")
        }
    }

    @Test func decodesBackendAccountTimestampWithFractionalSeconds() async throws {
        let body = Data(
            #"{"id":"account-1","kind":"account","version":1,"revision":1,"updated_at":"2026-09-25T12:34:56.123456Z","deleted":false,"data":{}}"#.utf8
        )
        let client = APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: makeSession(status: 200, body: body))

        let account = try await client.account(accessToken: "not-a-real-token")

        #expect(account.id == "account-1")
        #expect(account.updatedAt.timeIntervalSince1970 > 0)
    }

    @Test func frozenWriteSurvivesAuthenticationRetry() async throws {
        let session = queuedSession([.init(status: 401), .init(status: 200, body: Data("{}".utf8))])
        let client = APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: session)
        let tokens = TestTokens()
        let id = UUID(), key = UUID()
        var draft: JSONValue = .object(["nickname": .string("Original"), "home_base": .null])
        let operation = try APIRequest<JSONValue>.put(.traveler(id), body: draft, expectedVersion: 3, idempotencyKey: key)
        draft = .object(["nickname": .string("Changed after request construction")])
        _ = try await client.send(operation, using: tokens)
        let calls = StubURLProtocol.requests
        #expect(calls.count == 2)
        #expect(calls[0].url?.path == "/v1/travelers/\(id.uuidString.lowercased())")
        #expect(calls[0].httpMethod == "PUT")
        #expect(calls[0].value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(calls[0].value(forHTTPHeaderField: "Authorization") == "Bearer original-token")
        #expect(calls[1].value(forHTTPHeaderField: "Authorization") == "Bearer refreshed-token")
        for call in calls {
            #expect(call.value(forHTTPHeaderField: "Idempotency-Key") == key.uuidString.lowercased())
            #expect(call.value(forHTTPHeaderField: "X-Expected-Version") == "3")
        }
        #expect(StubURLProtocol.bodies[0] == operation.body)
        #expect(StubURLProtocol.bodies[0] == StubURLProtocol.bodies[1])
        let encoded = try APIJSON.decoder().decode(JSONValue.self, from: StubURLProtocol.bodies[0])
        #expect(encoded["nickname"] == .string("Original"))
        #expect(encoded["home_base"] == .null)
        #expect(await tokens.refreshFlags == [false, true])
    }

    @Test func secondUnauthorizedResponseDoesNotLoop() async throws {
        let client = APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: queuedSession([.init(status: 401), .init(status: 401)]))
        let tokens = TestTokens()
        await #expect(throws: APIClientError.unauthorized) { try await client.account(using: tokens) }
        #expect(StubURLProtocol.requests.count == 2)
        #expect(await tokens.refreshFlags == [false, true])
    }

    @Test func refreshFailureDoesNotSendAnotherWrite() async throws {
        let client = APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: queuedSession([.init(status: 401)]))
        let tokens = TestTokens(failRefresh: true)
        let operation = try APIRequest<JSONValue>.put(.journey(UUID()), body: JSONValue.object(["destinations": .array([.string("San Diego")])]), expectedVersion: 0)
        await #expect(throws: AuthenticationError.sessionExpired) { try await client.send(operation, using: tokens) }
        #expect(StubURLProtocol.requests.count == 1)
    }

    @Test func timeoutCanBeRetriedWithIdenticalOperation() async throws {
        let client = APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: queuedSession([.init(error: .timedOut), .init(status: 200, body: Data("{}".utf8))]))
        let operation = try APIRequest<JSONValue>.put(.journeyAction(UUID()), body: PipAction(action: "plan"), expectedVersion: 1)
        await #expect(throws: APIClientError.connection) { try await client.send(operation, accessToken: "token") }
        #expect(StubURLProtocol.requests.count == 1)
        _ = try await client.send(operation, accessToken: "token")
        #expect(StubURLProtocol.bodies[0] == StubURLProtocol.bodies[1])
        #expect(StubURLProtocol.requests[0].value(forHTTPHeaderField: "Idempotency-Key") == StubURLProtocol.requests[1].value(forHTTPHeaderField: "Idempotency-Key"))
        #expect(StubURLProtocol.requests[0].value(forHTTPHeaderField: "X-Expected-Version") == "1")
    }

    @Test func conflictPreservesServerRecordAndRequestWithoutRetry() async throws {
        let body = Data(#"{"error":{"code":"version_conflict","message":"Resolve conflict","request_id":"req-409","details":{"expected_version":1,"current":{"id":"me","kind":"profile","version":2,"revision":5,"updated_at":"2026-09-25T12:34:56Z","deleted":false,"data":{"nickname":"Server"}}}}}"#.utf8)
        let client = APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: queuedSession([.init(status: 409, body: body)]))
        let tokens = TestTokens()
        let operation = try APIRequest<JSONValue>.put(.preferences, body: JSONValue.object(["nickname": .string("Local")]), expectedVersion: 1)
        do {
            _ = try await client.send(operation, using: tokens)
            Issue.record("Expected a conflict")
        } catch APIClientError.conflict(let error, let requestID) {
            #expect(error.code == "version_conflict")
            #expect(error.details?["expected_version"] == .integer(1))
            #expect(error.currentRecord?.version == 2)
            #expect(error.currentRecord?.data["nickname"] == .string("Server"))
            #expect(requestID == "req-409")
        }
        #expect(operation.expectedVersion == 1)
        #expect(try APIJSON.decoder().decode(JSONValue.self, from: #require(operation.body))["nickname"] == .string("Local"))
        #expect(StubURLProtocol.requests.count == 1)
        #expect(await tokens.refreshFlags == [false])
    }

    @Test func nonVersionConflictRetainsItsCode() async throws {
        let body = Data(#"{"error":{"code":"idempotency_conflict","message":"Different request","details":null}}"#.utf8)
        let client = APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: queuedSession([.init(status: 409, body: body)]))
        do {
            _ = try await client.account(accessToken: "token")
            Issue.record("Expected conflict")
        } catch APIClientError.conflict(let error, _) {
            #expect(error.code == "idempotency_conflict")
            #expect(error.currentRecord == nil)
        }
    }

    @Test func validationErrorRetainsFieldDetailsAndHeaderRequestID() async throws {
        let body = Data(#"{"error":{"code":"validation_error","message":"Invalid request","details":[{"location":["body","destinations"],"message":"Required","type":"missing"}]}}"#.utf8)
        let client = APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: queuedSession([.init(status: 422, body: body, headers: ["X-Request-ID": "header-id"])]))
        do {
            _ = try await client.account(accessToken: "token")
            Issue.record("Expected validation error")
        } catch APIClientError.rejected(let status, let error, let requestID) {
            #expect(status == 422)
            #expect(error.code == "validation_error")
            #expect(requestID == "header-id")
            guard case .array(let fields) = error.details else { Issue.record("Missing field details"); return }
            #expect(fields.first?["location"] == .array([.string("body"), .string("destinations")]))
        }
    }

    @Test func preservesNotFoundAndDoesNotRetryServiceFailures() async throws {
        for status in [404, 429, 503] {
            let client = APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: queuedSession([.init(status: status, body: Data("<html>unavailable</html>".utf8))]))
            let tokens = TestTokens()
            do { _ = try await client.account(using: tokens); Issue.record("Expected failure") }
            catch APIClientError.rejected(let actual, let error, _) {
                #expect(actual == status)
                #expect(error.code == "http_error")
                #expect(!error.message.contains("html"))
            }
            #expect(StubURLProtocol.requests.count == 1)
            #expect(await tokens.refreshFlags == [false])
        }
    }

    @Test func decodesListsSyncAndTombstones() async throws {
        let record = #"{"id":"trip-id","kind":"trip","version":3,"revision":6,"updated_at":"2026-09-25T12:34:56.123456+00:00","deleted":true,"data":{}}"#
        let client = APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: queuedSession([
            .init(status: 200, body: Data("{\"items\":[\(record)]}".utf8)),
            .init(status: 200, body: Data("{\"cursor\":6,\"changes\":[\(record)]}".utf8))]))
        let list = try await client.send(APIRequest<APIRecordList<JSONValue>>.get(.journeys), accessToken: "token")
        #expect(list.items.first?.deleted == true)
        let sync = try await client.send(APIRequest<APISyncResponse>.get(.sync(after: 4)), accessToken: "token")
        #expect(sync.cursor == 6)
        #expect(sync.changes.first?.data == .object([:]))
        #expect(StubURLProtocol.requests.last?.url?.query == "after=4")
        #expect(StubURLProtocol.requests.last?.value(forHTTPHeaderField: "Idempotency-Key") == nil)
    }

    @Test func deleteUsesVersionAndKeyWithoutBody() async throws {
        let id = UUID()
        let client = APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: queuedSession([.init(status: 200, body: Data("{}".utf8))]))
        let operation = try APIRequest<JSONValue>.delete(.journey(id), expectedVersion: 2)
        _ = try await client.send(operation, accessToken: "token")
        let request = try #require(StubURLProtocol.requests.first)
        #expect(request.httpMethod == "DELETE")
        #expect(request.value(forHTTPHeaderField: "X-Expected-Version") == "2")
        #expect(request.value(forHTTPHeaderField: "Idempotency-Key") != nil)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == nil)
        #expect(StubURLProtocol.bodies.first?.isEmpty == true)
        let accountDelete = APIRequest<JSONValue>.deleteAccount()
        #expect(accountDelete.expectedVersion == nil)
        #expect(accountDelete.idempotencyKey == nil)
    }

    @Test func rejectsInvalidMethodsAndVersionsBeforeSending() throws {
        #expect(throws: APIClientError.self) { try APIRequest<JSONValue>.delete(.journey(UUID()), expectedVersion: 0) }
        #expect(throws: APIClientError.self) { try APIRequest<JSONValue>.put(.preferences, body: JSONValue.null, expectedVersion: -1) }
        #expect(throws: APIClientError.self) { try APIRequest<JSONValue>.post(.journeys, body: JSONValue.null) }
        #expect(throws: APIClientError.self) { try APIRequest<JSONValue>.get(.sync(after: -1)) }
    }


    @Test func cancellationIsNotConvertedToConnectionFailure() async throws {
        let client = APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: queuedSession([.init(error: .cancelled)]))
        do { _ = try await client.account(accessToken: "token"); Issue.record("Expected cancellation") }
        catch let error as URLError { #expect(error.code == .cancelled) }
        #expect(StubURLProtocol.requests.count == 1)
    }

    @Test func malformedSuccessfulResponseIsDecodingFailure() async throws {
        let client = APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: queuedSession([.init(status: 200, body: Data("{}".utf8))]))
        await #expect(throws: APIClientError.decoding) { try await client.account(accessToken: "token") }
    }



    private func queuedSession(_ responses: [StubReply]) -> URLSession {
        let session = makeSession(status: 200, body: Data())
        StubURLProtocol.replies = responses
        return session
    }



    @MainActor @Test func intakeTimeoutPreservesRequestAndDraft() async throws {
        let id = UUID()
        var intake = TripIntake(); intake.destination = "San Diego"
        let record = APIRecord(id: id.uuidString.lowercased(), kind: "journey", version: 1, revision: 2, updatedAt: Date(), deleted: false,
            data: Journey(intake: intake, messages: [], plan: [], proposal: nil, imports: [], onboarding_done: false, temporary_context: ""))
        let body = try APIJSON.encoder().encode(record)
        let client = APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: queuedSession([.init(error: .timedOut), .init(status: 200, body: body), .init(status: 200, body: body), .init(status: 200, body: Data(#"{"items":[]}"#.utf8))]))
        let store = IntelligenceStore(client: client, authentication: TestTokens())
        store.draft = intake; store.draftID = id
        await store.saveIntake()
        #expect(store.pending != nil); #expect(store.draft.destination == "San Diego")
        await store.retry()
        #expect(store.pending == nil); #expect(store.selected?.id == record.id)
        #expect(StubURLProtocol.bodies[0] == StubURLProtocol.bodies[1])
        #expect(StubURLProtocol.requests[0].value(forHTTPHeaderField: "Idempotency-Key") == StubURLProtocol.requests[1].value(forHTTPHeaderField: "Idempotency-Key"))
        #expect(StubURLProtocol.requests[2].httpMethod == "GET")
    }

    @MainActor @Test func intakeValidationFailureAllowsCorrection() async throws {
        let error = Data(#"{"error":{"code":"validation_error","message":"Provide timing"}}"#.utf8)
        let store = IntelligenceStore(client: APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: queuedSession([.init(status: 422, body: error)])), authentication: TestTokens())
        store.draft.destination = "Kyoto"
        await store.saveIntake()
        #expect(store.pending == nil); #expect(store.draft.destination == "Kyoto"); #expect(store.error == "Provide timing")
    }

    @MainActor @Test func memoryTimeoutRetainsExactOperation() async throws {
        let client = APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: queuedSession([
            .init(error: .timedOut), .init(status: 200, body: Data(#"{"id":"memory","kind":"memory","version":1,"revision":1,"updated_at":"2026-09-27T12:00:00Z","deleted":false,"data":{}}"#.utf8)),
            .init(status: 200, body: Data(#"{"items":[]}"#.utf8)), .init(status: 200, body: Data(#"{"items":[]}"#.utf8))]))
        let store = IntelligenceStore(client: client, authentication: TestTokens())
        var memory = TravelerMemory(); memory.key = "pace"; memory.value = "Room to explore"
        await store.saveMemory(memory)
        #expect(store.pendingAux != nil)
        await store.retryAux()
        #expect(store.pendingAux == nil)
        #expect(StubURLProtocol.bodies[0] == StubURLProtocol.bodies[1])
        #expect(StubURLProtocol.requests[0].value(forHTTPHeaderField: "Idempotency-Key") == StubURLProtocol.requests[1].value(forHTTPHeaderField: "Idempotency-Key"))
    }

    @MainActor @Test func signOutResetClearsAllProductState() {
        let store = IntelligenceStore(client: APIClient(baseURL: URL(string: "https://example.invalid")!), authentication: TestTokens())
        store.draft.destination = "Private trip"; store.composer = "Private message"; store.error = "Old error"; store.selectedID = UUID()
        store.reset()
        #expect(store.draft.destination.isEmpty); #expect(store.composer.isEmpty)
        #expect(store.selectedID == nil); #expect(store.memories.isEmpty); #expect(!store.hasPending)
    }

    private var configuration: AppConfiguration {
        AppConfiguration(cognitoDomain: URL(string: "https://auth.pippipgo.com")!, clientID: "test-client", callbackURL: URL(string: "pipgogo://auth/callback")!, logoutURL: URL(string: "pipgogo://auth/logout")!, backendBaseURL: URL(string: "https://example.invalid")!)
    }

    @Test func authorizationUsesPKCEAndState() throws {
        let client = CognitoClient(configuration: configuration)
        let url = try client.authorizationURL(state: "random-state", challenge: "challenge")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        let values = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        #expect(url.host == "auth.pippipgo.com")
        #expect(values["code_challenge_method"] == "S256")
        #expect(values["state"] == "random-state")
        #expect(values["redirect_uri"] == "pipgogo://auth/callback")
        #expect(values["identity_provider"] == "Google")
        #expect(values["prompt"] == "select_account")
    }

    @Test func exchangesCodeWithVerifierAndEncodedPlus() async throws {
        let body = Data(#"{"access_token":"access","refresh_token":"refresh","expires_in":900}"#.utf8)
        let client = CognitoClient(configuration: configuration, urlSession: makeSession(status: 200, body: body))
        let tokens = try await client.tokens(code: "code+value", verifier: "verifier")
        #expect(tokens.accessToken == "access")
        #expect(tokens.refreshToken == "refresh")
        let request = try #require(StubURLProtocol.request)
        #expect(request.url?.path == "/oauth2/token")
        #expect(request.httpMethod == "POST")
        let form = String(data: StubURLProtocol.requestBody, encoding: .utf8) ?? ""
        #expect(form.contains("code=code%2Bvalue"))
        #expect(form.contains("code_verifier=verifier"))
        #expect(form.contains("grant_type=authorization_code"))
    }

    @Test func refreshesAndPreservesRefreshToken() async throws {
        let body = Data(#"{"access_token":"new-access","expires_in":900}"#.utf8)
        let client = CognitoClient(configuration: configuration, urlSession: makeSession(status: 200, body: body))
        let old = TokenSet(accessToken: "old", idToken: nil, refreshToken: "refresh+token", tokenType: "Bearer", expiresAt: .distantPast)
        let tokens = try await client.refresh(old)
        #expect(tokens.accessToken == "new-access")
        #expect(tokens.refreshToken == "refresh+token")
        let form = String(data: StubURLProtocol.requestBody, encoding: .utf8) ?? ""
        #expect(form.contains("grant_type=refresh_token"))
        #expect(form.contains("refresh_token=refresh%2Btoken"))
    }

    @Test func revokesRefreshTokenAndBuildsLogout() async throws {
        let client = CognitoClient(configuration: configuration, urlSession: makeSession(status: 200, body: Data()))
        try await client.revoke(refreshToken: "refresh")
        #expect(StubURLProtocol.request?.url?.path == "/oauth2/revoke")
        #expect(String(data: StubURLProtocol.requestBody, encoding: .utf8)?.contains("token=refresh") == true)
        let url = try client.logoutURL()
        #expect(url.path == "/logout")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        #expect(items.contains(URLQueryItem(name: "logout_uri", value: "pipgogo://auth/logout")))
    }





    private func makeSession(status: Int, body: Data) -> URLSession {
        StubURLProtocol.response = HTTPURLResponse(url: URL(string: "https://example.invalid/v1/me")!, statusCode: status, httpVersion: nil, headerFields: nil)!
        StubURLProtocol.body = body
        StubURLProtocol.replies = []
        StubURLProtocol.requests = []
        StubURLProtocol.bodies = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var response: HTTPURLResponse!
    nonisolated(unsafe) static var body = Data()

    nonisolated(unsafe) static var request: URLRequest?
    nonisolated(unsafe) static var requestBody = Data()

    nonisolated(unsafe) static var replies: [StubReply] = []
    nonisolated(unsafe) static var requests: [URLRequest] = []
    nonisolated(unsafe) static var bodies: [Data] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.request = request
        Self.requestBody = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                Self.requestBody.append(contentsOf: buffer.prefix(count))
            }
        }
        Self.requests.append(request)
        Self.bodies.append(Self.requestBody)
        if !Self.replies.isEmpty {
            let reply = Self.replies.removeFirst()
            if let error = reply.error {
                client?.urlProtocol(self, didFailWithError: URLError(error))
                return
            }
            Self.response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: reply.headers)!
            Self.body = reply.body
        }
        client?.urlProtocol(self, didReceive: Self.response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private struct StubReply {
    var status: Int = 200
    var body = Data()
    var headers: [String: String] = [:]
    var error: URLError.Code? = nil
}

private actor TestTokens: AccessTokenProviding {
    var refreshFlags: [Bool] = []
    let failRefresh: Bool
    init(failRefresh: Bool = false) { self.failRefresh = failRefresh }
    func validAccessToken(forceRefresh: Bool) async throws -> String {
        refreshFlags.append(forceRefresh)
        if forceRefresh && failRefresh { throw AuthenticationError.sessionExpired }
        return forceRefresh ? "refreshed-token" : "original-token"
    }
}
