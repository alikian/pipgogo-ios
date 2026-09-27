import SwiftUI

struct RootView: View {
    let store: AuthenticationStore
    var environment: AppEnvironment = AppConfiguration.live.environment

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
                AccountView(account: account, isSigningOut: false, signOut: { Task { await store.signOut() } }, profileStore: store.profileStore, companionStore: store.companionStore, tripStore: store.tripStore, checkIns: store.checkIns)
            case .accountError(let message):
                AccountErrorView(message: message, retry: { Task { await store.loadAccount() } }, signOut: { Task { await store.signOut() } })
            case .signingOut:
                AccountView(account: nil, isSigningOut: true) {}
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BuildEnvironmentIndicator(environment: environment)
        }
        .animation(.easeInOut(duration: 0.2), value: store.state)
    }
}


struct BuildEnvironmentIndicator: View {
    let environment: AppEnvironment

    private var title: String {
        switch environment {
        case .local: "Local"
        case .dev: "Dev"
        case .prod: "Prod"
        }
    }

    private var color: Color {
        switch environment {
        case .local: .blue
        case .dev: .orange
        case .prod: .green
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7).accessibilityHidden(true)
            Text("Build: \(title)").font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Build environment: \(title)")
        .accessibilityIdentifier("app.buildEnvironment")
    }
}
