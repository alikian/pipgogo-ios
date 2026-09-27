import SwiftUI

struct AccountLoadingView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ProgressView()
                Text("Loading your account…")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("PipPipGo")
        }
    }
}

struct AccountErrorView: View {
    let message: String
    let retry: () -> Void
    let signOut: () -> Void

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Account unavailable", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try again", action: retry).buttonStyle(.borderedProminent)
                Button("Sign out", role: .destructive, action: signOut)
            }
            .navigationTitle("PipPipGo")
        }
    }
}
