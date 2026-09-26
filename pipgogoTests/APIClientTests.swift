import Foundation
import Testing
@testable import pipgogo

@Suite(.serialized)
struct APIClientTests {
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
        let operation = try APIRequest<JSONValue>.put(.companion(id), body: draft, expectedVersion: 3, idempotencyKey: key)
        draft = .object(["nickname": .string("Changed after request construction")])
        _ = try await client.send(operation, using: tokens)
        let calls = StubURLProtocol.requests
        #expect(calls.count == 2)
        #expect(calls[0].url?.path == "/v1/companions/\(id.uuidString.lowercased())")
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
        let operation = try APIRequest<JSONValue>.put(.trip(UUID()), body: JSONValue.object(["destinations": .array([.string("San Diego")])]), expectedVersion: 0)
        await #expect(throws: AuthenticationError.sessionExpired) { try await client.send(operation, using: tokens) }
        #expect(StubURLProtocol.requests.count == 1)
    }

    @Test func timeoutCanBeRetriedWithIdenticalOperation() async throws {
        let client = APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: queuedSession([.init(error: .timedOut), .init(status: 200, body: Data("{}".utf8))]))
        let operation = try APIRequest<JSONValue>.post(.packages(UUID()), body: JSONValue.object(["include_profile": .bool(false)]))
        await #expect(throws: APIClientError.connection) { try await client.send(operation, accessToken: "token") }
        #expect(StubURLProtocol.requests.count == 1)
        _ = try await client.send(operation, accessToken: "token")
        #expect(StubURLProtocol.bodies[0] == StubURLProtocol.bodies[1])
        #expect(StubURLProtocol.requests[0].value(forHTTPHeaderField: "Idempotency-Key") == StubURLProtocol.requests[1].value(forHTTPHeaderField: "Idempotency-Key"))
        #expect(StubURLProtocol.requests[0].value(forHTTPHeaderField: "X-Expected-Version") == nil)
    }

    @Test func conflictPreservesServerRecordAndRequestWithoutRetry() async throws {
        let body = Data(#"{"error":{"code":"version_conflict","message":"Resolve conflict","request_id":"req-409","details":{"expected_version":1,"current":{"id":"me","kind":"profile","version":2,"revision":5,"updated_at":"2026-09-25T12:34:56Z","deleted":false,"data":{"nickname":"Server"}}}}}"#.utf8)
        let client = APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: queuedSession([.init(status: 409, body: body)]))
        let tokens = TestTokens()
        let operation = try APIRequest<JSONValue>.put(.profile, body: JSONValue.object(["nickname": .string("Local")]), expectedVersion: 1)
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
        let list = try await client.send(APIRequest<APIRecordList<JSONValue>>.get(.trips), accessToken: "token")
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
        let operation = try APIRequest<JSONValue>.delete(.trip(id), expectedVersion: 2)
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
        #expect(throws: APIClientError.self) { try APIRequest<JSONValue>.delete(.trip(UUID()), expectedVersion: 0) }
        #expect(throws: APIClientError.self) { try APIRequest<JSONValue>.put(.profile, body: JSONValue.null, expectedVersion: -1) }
        #expect(throws: APIClientError.self) { try APIRequest<JSONValue>.post(.trips, body: JSONValue.null) }
        #expect(throws: APIClientError.self) { try APIRequest<JSONValue>.get(.sync(after: -1)) }
    }

    @Test func downloadReturnsExactAuthenticatedJSONBytes() async throws {
        let trip = UUID(), package = UUID(), body = Data("{\"status\":\"partial\"}\n".utf8)
        let client = APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: queuedSession([.init(status: 401), .init(status: 200, body: body)]))
        let result = try await client.downloadPackage(tripID: trip, packageID: package, using: TestTokens())
        #expect(result == body)
        #expect(StubURLProtocol.requests.last?.url?.path == "/v1/trips/\(trip.uuidString.lowercased())/companion-package/\(package.uuidString.lowercased())/download")
        #expect(StubURLProtocol.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer refreshed-token")
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

    @Test func profileServiceTreatsOnlyMissingRecordAsEmpty() async throws {
        let missing = Data(#"{"error":{"code":"not_found","message":"Record not found"}}"#.utf8)
        let service = ProfileService(client: APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: queuedSession([.init(status: 404, body: missing)])), authentication: TestTokens())
        #expect(try await service.load() == nil)
        #expect(StubURLProtocol.requests.first?.url?.path == "/v1/traveler-profile")
        let denied = Data(#"{"error":{"code":"account_deleted","message":"Disabled"}}"#.utf8)
        let rejected = ProfileService(client: APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: queuedSession([.init(status: 403, body: denied)])), authentication: TestTokens())
        await #expect(throws: APIClientError.self) { try await rejected.load() }
    }

    @Test func profileServiceDecodesBackendNullsAndSendsClearedPreferences() async throws {
        let response = Data(#"{"id":"me","kind":"profile","version":2,"revision":4,"updated_at":"2026-09-25T12:34:56Z","deleted":false,"data":{"nickname":null,"home_base":null,"age_range":null,"usual_party":null,"preferences":{"languages":[],"interests":[],"dietary_needs":[],"accessibility_needs":[],"pace":null,"budget_comfort":null,"transportation":[]}}}"#.utf8)
        let service = ProfileService(client: APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: queuedSession([.init(status: 200, body: response)])), authentication: TestTokens())
        let operation = try APIRequest<APIRecord<TravelerProfile>>.put(.profile, body: TravelerProfile(), expectedVersion: 1)
        let saved = try await service.save(operation)
        #expect(saved.version == 2)
        #expect(saved.data == TravelerProfile())
        let body = try APIJSON.decoder().decode(JSONValue.self, from: StubURLProtocol.requestBody)
        #expect(body["preferences"]?["accessibility_needs"] == .array([]))
        #expect(StubURLProtocol.requests.first?.value(forHTTPHeaderField: "X-Expected-Version") == "1")
    }

    private var configuration: AppConfiguration {
        AppConfiguration(cognitoDomain: URL(string: "https://auth.pipgogo.com")!, clientID: "test-client", callbackURL: URL(string: "pipgogo://auth/callback")!, logoutURL: URL(string: "pipgogo://auth/logout")!, backendBaseURL: URL(string: "https://example.invalid")!)
    }

    @Test func authorizationUsesPKCEAndState() throws {
        let client = CognitoClient(configuration: configuration)
        let url = try client.authorizationURL(state: "random-state", challenge: "challenge")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        let values = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        #expect(url.host == "auth.pipgogo.com")
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

    @Test func companionServiceUsesAuthenticatedListPutAndTombstoneDelete() async throws {
        let id = UUID()
        let body = Companion(nickname: "Sam", relationship: "Friend", ageRange: "30–39", preferences: TravelerPreferences(languages: ["English"], interests: ["Art"], dietaryNeeds: ["Vegetarian"], accessibilityNeeds: ["Step-free"], pace: "relaxed", budgetComfort: "moderate", transportation: ["Train"]))
        let record = APIRecord(id: id.uuidString.lowercased(), kind: "companion", version: 1, revision: 4, updatedAt: Date(timeIntervalSince1970: 1_800_000_000), deleted: false, data: body)
        let tombstone = APIRecord(id: record.id, kind: "companion", version: 2, revision: 5, updatedAt: record.updatedAt, deleted: true, data: JSONValue.object([:]))
        let session = queuedSession([
            .init(body: try APIJSON.encoder().encode(APIRecordList(items: [record]))),
            .init(body: try APIJSON.encoder().encode(record)),
            .init(body: try APIJSON.encoder().encode(tombstone))
        ])
        let service = CompanionService(client: APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: session), authentication: TestTokens())
        #expect(try await service.list() == [record])
        let save = try APIRequest<APIRecord<JSONValue>>.put(.companion(id), body: body, expectedVersion: 0)
        #expect(try await service.mutate(save).companion().data == body)
        let delete = try APIRequest<APIRecord<JSONValue>>.delete(.companion(id), expectedVersion: 1)
        let removed = try await service.mutate(delete)
        #expect(removed.deleted && removed.data == .object([:]))
        let calls = StubURLProtocol.requests
        #expect(calls.map(\.httpMethod) == ["GET", "PUT", "DELETE"])
        #expect(calls[0].url?.path == "/v1/companions")
        #expect(calls[1].url?.path == "/v1/companions/\(record.id)")
        #expect(calls[1].value(forHTTPHeaderField: "X-Expected-Version") == "0")
        #expect(calls[2].value(forHTTPHeaderField: "X-Expected-Version") == "1")
        #expect(calls[2].value(forHTTPHeaderField: "Idempotency-Key") == delete.idempotencyKey?.uuidString.lowercased())
        #expect(calls.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer original-token" })
        let encoded = try APIJSON.decoder().decode(JSONValue.self, from: StubURLProtocol.bodies[1])
        #expect(encoded["age_range"] == .string("30–39"))
        #expect(encoded["preferences"]?["accessibility_needs"] == .array([.string("Step-free")]))
        #expect(StubURLProtocol.bodies[2].isEmpty)
    }

    @Test func companionServicePreservesInUseErrorCode() async throws {
        let payload = Data(#"{"error":{"code":"companion_in_use","message":"Remove the companion from trips first"}}"#.utf8)
        let client = APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: makeSession(status: 409, body: payload))
        let service = CompanionService(client: client, authentication: TestTokens())
        let request = try APIRequest<APIRecord<JSONValue>>.delete(.companion(UUID()), expectedVersion: 1)
        await #expect(throws: APIClientError.conflict(APIErrorBody(code: "companion_in_use", message: "Remove the companion from trips first"), requestID: nil)) {
            try await service.mutate(request)
        }
    }

    @Test func tripServiceReadsBackendNullsAndSendsCreationContract() async throws {
        let id = UUID()
        let companionID = UUID().uuidString.lowercased()
        let payload = Data("""
        {"id":"\(id.uuidString.lowercased())","kind":"trip","version":1,"revision":2,"updated_at":"2026-09-26T10:00:00.123456Z","deleted":false,"data":{"destinations":["Japan"],"start_date":"2026-11-01","end_date":null,"accommodation":{"name":"Hotel","address":null,"check_in":null,"instructions":null,"reservation_reference":null},"arrival":null,"departure":null,"companion_ids":["\(companionID)"],"preferences":{"languages":[],"interests":[],"dietary_needs":[],"accessibility_needs":[],"pace":null,"budget_comfort":null,"transportation":[]},"budget_minor":null,"currency":null,"transportation_plan":null,"itinerary":[],"constraints":[]}}
        """.utf8)
        let list = Data("{\"items\":[".utf8) + payload + Data("]}".utf8)
        let session = queuedSession([.init(body: list), .init(body: payload), .init(body: payload)])
        let service = TripService(client: APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: session), authentication: TestTokens())
        let records = try await service.list()
        let record = try await service.load(id)
        #expect(records.first == record)
        #expect(record.data.endDate == nil && record.data.arrival == nil)
        let request = try APIRequest<APIRecord<Trip>>.put(.trip(id), body: record.data, expectedVersion: 0)
        _ = try await service.save(request)
        let calls = StubURLProtocol.requests
        #expect(calls.map(\.httpMethod) == ["GET", "GET", "PUT"])
        #expect(calls[0].url?.path == "/v1/trips")
        #expect(calls[2].url?.path == "/v1/trips/\(id.uuidString.lowercased())")
        #expect(calls[2].value(forHTTPHeaderField: "X-Expected-Version") == "0")
        #expect(calls[2].value(forHTTPHeaderField: "Idempotency-Key") == request.idempotencyKey?.uuidString.lowercased())
        #expect(calls.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer original-token" })
        let encoded = try APIJSON.decoder().decode(JSONValue.self, from: StubURLProtocol.bodies[2])
        #expect(encoded["start_date"] == .string("2026-11-01"))
        #expect(encoded["companion_ids"] == .array([.string(companionID)]))
    }

    @Test func tripUpdateAndDeleteUseVersionsAndDecodeEmptyTombstone() async throws {
        let id = UUID()
        let body = Trip(destinations: ["Kyoto"], companionIDs: [], itinerary: ["Garden"])
        let record = APIRecord(id: id.uuidString.lowercased(), kind: "trip", version: 4, revision: 7, updatedAt: Date(), deleted: false, data: body)
        let tombstone = APIRecord(id: record.id, kind: "trip", version: 5, revision: 8, updatedAt: record.updatedAt, deleted: true, data: JSONValue.object([:]))
        let session = queuedSession([.init(body: try APIJSON.encoder().encode(record)), .init(body: try APIJSON.encoder().encode(tombstone))])
        let service = TripService(client: APIClient(baseURL: URL(string: "https://example.invalid")!, urlSession: session), authentication: TestTokens())
        let update = try APIRequest<APIRecord<Trip>>.put(.trip(id), body: body, expectedVersion: 3)
        #expect(try await service.save(update).data == body)
        let deletion = try APIRequest<APIRecord<JSONValue>>.delete(.trip(id), expectedVersion: 4)
        let result = try await service.delete(deletion)
        #expect(result.deleted && result.data == .object([:]))
        let calls = StubURLProtocol.requests
        #expect(calls.map(\.httpMethod) == ["PUT", "DELETE"])
        #expect(calls[0].value(forHTTPHeaderField: "X-Expected-Version") == "3")
        #expect(calls[1].value(forHTTPHeaderField: "X-Expected-Version") == "4")
        #expect(calls[1].value(forHTTPHeaderField: "Idempotency-Key") == deletion.idempotencyKey?.uuidString.lowercased())
        #expect(calls[1].url?.path == "/v1/trips/\(record.id)" && StubURLProtocol.bodies[1].isEmpty)
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
