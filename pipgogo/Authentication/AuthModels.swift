import Foundation

struct TokenSet: Codable, Equatable, Sendable {
    let accessToken: String
    let idToken: String?
    let refreshToken: String?
    let tokenType: String
    let expiresAt: Date

    var needsRefresh: Bool { expiresAt.timeIntervalSinceNow < 60 }

    func replacing(with response: TokenResponse, now: Date = .now) throws -> TokenSet {
        guard let accessToken = response.accessToken else { throw AuthenticationError.invalidTokenResponse }
        return TokenSet(accessToken: accessToken, idToken: response.idToken ?? idToken, refreshToken: response.refreshToken ?? refreshToken, tokenType: response.tokenType ?? tokenType, expiresAt: now.addingTimeInterval(TimeInterval(response.expiresIn ?? 3600)))
    }
}

struct TokenResponse: Decodable, Sendable {
    let accessToken: String?
    let idToken: String?
    let refreshToken: String?
    let tokenType: String?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case idToken = "id_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

enum AuthenticationError: LocalizedError, Equatable {
    case cancelled
    case invalidCallback
    case stateMismatch
    case authorizationFailed(String)
    case invalidTokenResponse
    case noRefreshToken
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .cancelled: "Sign-in was cancelled."
        case .invalidCallback: "Cognito returned an invalid sign-in response."
        case .stateMismatch: "The sign-in response could not be verified. Please try again."
        case .authorizationFailed(let message): message
        case .invalidTokenResponse: "Cognito returned an invalid token response."
        case .noRefreshToken, .sessionExpired: "Your session has expired. Please sign in again."
        }
    }
}
