import SwiftUI

struct AccountView: View {
    let account: AccountRecord?
    let isSigningOut: Bool
    let signOut: () -> Void
    var profileStore: ProfileStore? = nil
    var companionStore: CompanionStore? = nil
    var tripStore: TripStore? = nil

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Signed in with Google", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    if let account {
                        LabeledContent("Account", value: account.id)
                        LabeledContent("Connected", value: account.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                } header: {
                    Text("Your account")
                } footer: {
                    Text("PipGoGo uses your Cognito access token only for authenticated backend requests.")
                }

                if let tripStore, let companionStore {
                    Section {
                        NavigationLink { TripListView(store: tripStore, companions: companionStore) } label: {
                            Label("Trips", systemImage: "suitcase.rolling")
                        }.disabled(isSigningOut)
                    }
                }
                if let profileStore {
                    Section {
                        NavigationLink { ProfileView(store: profileStore) } label: {
                            Label("Traveler profile", systemImage: "person.text.rectangle")
                        }.disabled(isSigningOut)
                    }
                }
                if let companionStore {
                    Section {
                        NavigationLink { CompanionListView(store: companionStore) } label: {
                            Label("Companions", systemImage: "person.2")
                        }.disabled(isSigningOut)
                    }
                }
                Section {
                    Button(role: .destructive, action: signOut) {
                        HStack {
                            Text(isSigningOut ? "Signing out…" : "Sign out")
                            if isSigningOut { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(isSigningOut)
                }
            }
            .navigationTitle("PipGoGo")
        }
    }
}

struct AccountLoadingView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ProgressView()
                Text("Loading your account…")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("PipGoGo")
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
            .navigationTitle("PipGoGo")
        }
    }
}
