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
    let profileStore: ProfileStore
    let companionStore: CompanionStore
    let tripStore: TripStore
    private let configuration: AppConfiguration
    private let authentication: AuthenticationService
    private let apiClient: APIClient
    private let webAuthentication = WebAuthenticationSession()

    init(configuration: AppConfiguration = .live, authentication: AuthenticationService? = nil, apiClient: APIClient? = nil) {
        let auth = authentication ?? AuthenticationService(configuration: configuration)
        let client = apiClient ?? APIClient(baseURL: configuration.backendBaseURL)
        profileStore = ProfileStore(service: ProfileService(client: client, authentication: auth))
        companionStore = CompanionStore(service: CompanionService(client: client, authentication: auth))
        tripStore = TripStore(service: TripService(client: client, authentication: auth))
        self.configuration = configuration
        self.authentication = auth
        self.apiClient = client
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
        profileStore.reset()
        companionStore.reset()
        tripStore.reset()
        state = .signingIn
        do {
            let verifier = try PKCE.randomURLSafeString(byteCount: 64)
            let stateValue = try PKCE.randomURLSafeString()
            let url = try await authentication.authorizationURL(state: stateValue, challenge: PKCE.challenge(for: verifier))
            // Managed Login forwards select_account to Google. Share browser cookies
            // so Google can offer existing browser accounts rather than require email entry.
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
            state = .signedIn(try await apiClient.account(using: authentication))
        } catch {
            state = .accountError(error.localizedDescription)
        }
    }

    func signOut() async {
        profileStore.reset()
        companionStore.reset()
        tripStore.reset()
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
