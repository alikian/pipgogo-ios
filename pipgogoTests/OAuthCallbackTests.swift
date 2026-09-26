import Foundation
import Testing
@testable import pipgogo

struct OAuthCallbackTests {
    private let callback = URL(string: "pipgogo://auth/callback")!

    @Test func acceptsMatchingCallbackAndState() throws {
        let url = URL(string: "pipgogo://auth/callback?code=abc&state=expected")!
        #expect(try OAuthCallback.authorizationCode(from: url, expectedCallback: callback, expectedState: "expected") == "abc")
    }

    @Test func rejectsMismatchedState() {
        let url = URL(string: "pipgogo://auth/callback?code=abc&state=wrong")!
        #expect(throws: AuthenticationError.stateMismatch) {
            try OAuthCallback.authorizationCode(from: url, expectedCallback: callback, expectedState: "expected")
        }
    }

    @Test func rejectsDifferentCallbackPath() {
        let url = URL(string: "pipgogo://auth/other?code=abc&state=expected")!
        #expect(throws: AuthenticationError.invalidCallback) {
            try OAuthCallback.authorizationCode(from: url, expectedCallback: callback, expectedState: "expected")
        }
    }

    @Test func pkceChallengeMatchesKnownVector() {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        #expect(PKCE.challenge(for: verifier) == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }
}
