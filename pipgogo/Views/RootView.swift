import SwiftUI

struct RootView: View {
    let store: AuthenticationStore

    var body: some View {
        Group {
            switch store.state {
            case .restoring:
                ProgressView("Restoring your session…")
            case .signedOut:
                WelcomeView(isBusy: false, errorMessage: nil) { Task { await store.signIn() } }
            case .signingIn:
                WelcomeView(isBusy: true, errorMessage: nil) {}
            case .signInError(let message):
                WelcomeView(isBusy: false, errorMessage: message) { Task { await store.signIn() } }
            case .loadingAccount:
                AccountLoadingView()
            case .signedIn(let account):
                AccountView(account: account, isSigningOut: false, signOut: { Task { await store.signOut() } }, profileStore: store.profileStore)
            case .accountError(let message):
                AccountErrorView(message: message, retry: { Task { await store.loadAccount() } }, signOut: { Task { await store.signOut() } })
            case .signingOut:
                AccountView(account: nil, isSigningOut: true) {}
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.state)
    }
}
