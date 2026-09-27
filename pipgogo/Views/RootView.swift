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
            case .signedIn:
                PipHomeView(store: store.intelligence, signOut: { Task { await store.signOut() } })
            case .accountError(let message):
                AccountErrorView(message: message, retry: { Task { await store.loadAccount() } }, signOut: { Task { await store.signOut() } })
            case .signingOut:
                ProgressView("Signing out…")
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Spacer()
                BuildEnvironmentIndicator(environment: environment)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
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
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5).accessibilityHidden(true)
            Text("Build: \(title)").font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.regularMaterial, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Build environment: \(title)")
        .accessibilityIdentifier("app.buildEnvironment")
    }
}
