import Foundation
import Observation

@MainActor
@Observable
final class AuthenticationStore {
    enum State: Equatable {
        case restoring
        case signedOut
        case signingIn
        case loadingAccount
        case signedIn(AccountRecord)
        case accountError(String)
        case signInError(String)
        case signingOut
    }

    private(set) var state: State = .restoring
    private let configuration: AppConfiguration
    private let authentication: AuthenticationService
    private let apiClient: APIClient
    private let webAuthentication = WebAuthenticationSession()

    init(configuration: AppConfiguration = .live, authentication: AuthenticationService? = nil, apiClient: APIClient? = nil) {
        self.configuration = configuration
        self.authentication = authentication ?? AuthenticationService(configuration: configuration)
        self.apiClient = apiClient ?? APIClient(baseURL: configuration.backendBaseURL)
    }

    func restoreSession() async {
        guard state == .restoring else { return }
        do {
            if try await authentication.restore() { await loadAccount() } else { state = .signedOut }
        } catch {
            state = .signInError(error.localizedDescription)
        }
    }

    func signIn() async {
        state = .signingIn
        do {
            let verifier = try PKCE.randomURLSafeString(byteCount: 64)
            let stateValue = try PKCE.randomURLSafeString()
            let url = try await authentication.authorizationURL(state: stateValue, challenge: PKCE.challenge(for: verifier))
            let callback = try await webAuthentication.authenticate(url: url, callbackScheme: configuration.callbackURL.scheme ?? "pipgogo", prefersEphemeral: false)
            let code = try OAuthCallback.authorizationCode(from: callback, expectedCallback: configuration.callbackURL, expectedState: stateValue)
            try await authentication.completeSignIn(code: code, verifier: verifier)
            await loadAccount()
        } catch AuthenticationError.cancelled {
            state = .signedOut
        } catch {
            state = .signInError(error.localizedDescription)
        }
    }

    func loadAccount() async {
        state = .loadingAccount
        do {
            let token = try await authentication.validAccessToken()
            state = .signedIn(try await apiClient.account(accessToken: token))
        } catch APIClientError.unauthorized {
            do {
                let refreshedToken = try await authentication.validAccessToken(forceRefresh: true)
                state = .signedIn(try await apiClient.account(accessToken: refreshedToken))
            } catch {
                state = .accountError(error.localizedDescription)
            }
        } catch {
            state = .accountError(error.localizedDescription)
        }
    }

    func signOut() async {
        state = .signingOut
        var message: String?
        do { try await authentication.clearAndRevoke() }
        catch { message = "The local session was cleared, but Cognito token revocation could not be confirmed." }

        do {
            let logoutURL = try await authentication.logoutURL()
            let callback = try await webAuthentication.authenticate(url: logoutURL, callbackScheme: configuration.logoutURL.scheme ?? "pipgogo", prefersEphemeral: false)
            try OAuthCallback.validateLogout(callback, expectedCallback: configuration.logoutURL)
        } catch AuthenticationError.cancelled {
            message = message ?? "You are signed out locally. Cognito browser logout was cancelled."
        } catch {
            message = message ?? "You are signed out locally. Cognito browser logout could not be confirmed."
        }
        state = message.map(State.signInError) ?? .signedOut
    }
}
