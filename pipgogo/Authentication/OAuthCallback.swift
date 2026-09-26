import Foundation

enum OAuthCallback {
    static func authorizationCode(from url: URL, expectedCallback: URL, expectedState: String) throws -> String {
        guard url.scheme == expectedCallback.scheme, url.host == expectedCallback.host, url.path == expectedCallback.path,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw AuthenticationError.invalidCallback
        }
        let values = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        guard values["state"] == expectedState else { throw AuthenticationError.stateMismatch }
        if let error = values["error"] {
            throw AuthenticationError.authorizationFailed(values["error_description"] ?? error)
        }
        guard let code = values["code"], !code.isEmpty else { throw AuthenticationError.invalidCallback }
        return code
    }

    static func validateLogout(_ url: URL, expectedCallback: URL) throws {
        guard url.scheme == expectedCallback.scheme, url.host == expectedCallback.host, url.path == expectedCallback.path else {
            throw AuthenticationError.invalidCallback
        }
    }
}
