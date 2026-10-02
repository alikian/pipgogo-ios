import Foundation

struct CognitoClient: Sendable {
    let configuration: AppConfiguration
    var urlSession: URLSession = .shared

    func authorizationURL(state: String, challenge: String) throws -> URL {
        var queryItems: [URLQueryItem] = [
            .init(name: "client_id", value: configuration.clientID), .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "openid email profile"), .init(name: "redirect_uri", value: configuration.callbackURL.absoluteString),
            .init(name: "prompt", value: "select_account"), .init(name: "state", value: state),
            .init(name: "code_challenge_method", value: "S256"), .init(name: "code_challenge", value: challenge)
        ]
        if configuration.environment == .prod {
            queryItems.append(.init(name: "identity_provider", value: "Google"))
        }
        return try endpoint("/oauth2/authorize", queryItems: queryItems)
    }

    func tokens(code: String, verifier: String) async throws -> TokenSet {
        let response: TokenResponse = try await formRequest(path: "/oauth2/token", values: [
            "grant_type": "authorization_code", "client_id": configuration.clientID, "code": code,
            "redirect_uri": configuration.callbackURL.absoluteString, "code_verifier": verifier
        ])
        guard let accessToken = response.accessToken else { throw AuthenticationError.invalidTokenResponse }
        return TokenSet(accessToken: accessToken, idToken: response.idToken, refreshToken: response.refreshToken, tokenType: response.tokenType ?? "Bearer", expiresAt: .now.addingTimeInterval(TimeInterval(response.expiresIn ?? 3600)))
    }

    func refresh(_ tokens: TokenSet) async throws -> TokenSet {
        guard let refreshToken = tokens.refreshToken else { throw AuthenticationError.noRefreshToken }
        let response: TokenResponse = try await formRequest(path: "/oauth2/token", values: [
            "grant_type": "refresh_token", "client_id": configuration.clientID, "refresh_token": refreshToken
        ])
        return try tokens.replacing(with: response)
    }

    func revoke(refreshToken: String) async throws {
        let _: EmptyResponse = try await formRequest(path: "/oauth2/revoke", values: ["client_id": configuration.clientID, "token": refreshToken], allowsEmptyResponse: true)
    }

    func profile(accessToken: String) async throws -> SignedInProfile {
        var request = URLRequest(url: try endpoint("/oauth2/userInfo"), cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(SignedInProfile.self, from: data)
    }

    func logoutURL() throws -> URL {
        try endpoint("/logout", queryItems: [.init(name: "client_id", value: configuration.clientID), .init(name: "logout_uri", value: configuration.logoutURL.absoluteString)])
    }

    private func endpoint(_ path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        let url = configuration.cognitoDomain.appending(path: path)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let result = components.url else { throw URLError(.badURL) }
        return result
    }

    private func formRequest<Response: Decodable>(path: String, values: [String: String], allowsEmptyResponse: Bool = false) async throws -> Response {
        var request = URLRequest(url: try endpoint(path))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = URLComponents.formBody(values)
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else { throw AuthenticationError.authorizationFailed("Cognito could not complete authentication (HTTP \(http.statusCode)).") }
        if allowsEmptyResponse, data.isEmpty, let empty = EmptyResponse() as? Response { return empty }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}

private struct EmptyResponse: Decodable { init() {} }

private extension URLComponents {
    static func formBody(_ values: [String: String]) -> Data? {
        var components = URLComponents()
        components.queryItems = values.sorted(by: { $0.key < $1.key }).map { URLQueryItem(name: $0.key, value: $0.value) }
        return components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B").data(using: .utf8)
    }
}
