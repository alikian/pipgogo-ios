import Foundation
import Testing
@testable import pipgogo

struct TokenSetTests {
    @Test func refreshPreservesRotatedFieldsWhenOmitted() throws {
        let original = TokenSet(accessToken: "old", idToken: "identity", refreshToken: "refresh", tokenType: "Bearer", expiresAt: .distantPast)
        let response = TokenResponse(accessToken: "new", idToken: nil, refreshToken: nil, tokenType: nil, expiresIn: 120)
        let updated = try original.replacing(with: response, now: Date(timeIntervalSince1970: 1_000))
        #expect(updated.accessToken == "new")
        #expect(updated.idToken == "identity")
        #expect(updated.refreshToken == "refresh")
        #expect(updated.expiresAt == Date(timeIntervalSince1970: 1_120))
    }

    @Test func refreshRequiresAccessToken() {
        let original = TokenSet(accessToken: "old", idToken: nil, refreshToken: "refresh", tokenType: "Bearer", expiresAt: .distantPast)
        let response = TokenResponse(accessToken: nil, idToken: nil, refreshToken: nil, tokenType: nil, expiresIn: nil)
        #expect(throws: AuthenticationError.invalidTokenResponse) { try original.replacing(with: response) }
    }
}
