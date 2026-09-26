import SwiftUI

struct ProfileView: View {
    @Bindable var store: ProfileStore
    @State private var confirmDiscard = false
    @State private var confirmUseSaved = false

    var body: some View {
        Form {
            if !store.loaded {
                if store.busy { ProgressView("Loading your profile…") }
                else if let message = store.errorMessage {
                    Text(message).foregroundStyle(.red)
                    Button("Try again") { Task { await store.load() } }
                }
            } else {
                Section {
                    Text(store.saved == nil ? "Make this profile yours" : "Your travel preferences")
                        .font(.headline)
                    Text("Everything here is optional. Share only what helps plan your trip. Clear an entry and save to remove it.")
                        .foregroundStyle(.secondary)
                }
                if let conflict = store.conflict {
                    Section("Profile changed elsewhere") {
                        Text("Your draft is safe. Compare it with the saved profile before choosing what to keep.")
                        let remote = (conflict.saved?.data ?? TravelerProfile()).summary
                        ForEach(Array(store.draft.summary.enumerated()), id: \.offset) { index, row in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.0).font(.headline)
                                Text("Your draft: \(row.1)")
                                Text("Saved: \(remote[index].1)").foregroundStyle(.secondary)
                            }
                        }
                        Button("Keep my draft") { store.keepDraft() }
                        Button("Use saved profile", role: .destructive) { confirmUseSaved = true }
                    }
                }
                Group {
                    Section("About you") {
                        TextField("Name or nickname", text: optional(\.nickname))
                        TextField("Home base", text: optional(\.homeBase))
                        TextField("Age range (optional)", text: optional(\.ageRange))
                        Picker("Usually traveling", selection: optional(\.usualParty)) {
                            Text("Not set").tag("")
                            Text("Alone").tag("alone")
                            Text("With others").tag("others")
                            Text("Both").tag("both")
                        }
                    }
                    Section {
                        LanguageSelectionView(languages: $store.draft.preferences.languages)
                        entries("Interests", values: $store.draft.preferences.interests)
                        entries("Dietary needs", values: $store.draft.preferences.dietaryNeeds)
                        entries("Accessibility needs", values: $store.draft.preferences.accessibilityNeeds)
                        entries("Transportation preferences", values: $store.draft.preferences.transportation)
                    } header: { Text("Preferences") } footer: {
                        Text("For text preferences, use one entry per line, up to 30 per list. Each entry can contain up to 300 characters.")
                    }
                    Section("Travel style") {
                        Picker("Pace", selection: preference(\.pace)) {
                            Text("Not set").tag("")
                            Text("Relaxed").tag("relaxed")
                            Text("Balanced").tag("balanced")
                            Text("Active").tag("active")
                        }
                        Picker("Budget comfort", selection: preference(\.budgetComfort)) {
                            Text("Not set").tag("")
                            Text("Economy").tag("economy")
                            Text("Moderate").tag("moderate")
                            Text("Premium").tag("premium")
                        }
                    }
                }.disabled(!store.canEdit)
                Section {
                    if let error = store.errorMessage { Text(error).foregroundStyle(.red) }
                    if store.pending != nil && !store.busy {
                        Text("The save has not been confirmed. Retry it before making more changes. Your draft is kept while you stay signed in.")
                    }
                    if let notice = store.notice { Text(notice).foregroundStyle(.secondary) }
                    Button { Task { await store.save() } } label: {
                        HStack {
                            Text(store.pending != nil ? "Retry save" : "Save profile")
                            if store.busy { Spacer(); ProgressView() }
                        }
                    }.disabled(!store.canSave)
                    if store.dirty && store.canEdit {
                        Button("Discard changes", role: .destructive) { confirmDiscard = true }
                    }
                } footer: {
                    Text("Unsaved changes stay in this app session. They are cleared when you sign out or close the app completely.")
                }
            }
        }
        .navigationTitle("Traveler profile")
        .task { await store.load() }
        .confirmationDialog("Discard your unsaved changes?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard changes", role: .destructive) { store.discardChanges() }
        }
        .confirmationDialog("Replace your draft with the saved profile?", isPresented: $confirmUseSaved, titleVisibility: .visible) {
            Button("Use saved profile", role: .destructive) { store.useSavedProfile() }
        }
    }

    private func optional(_ path: WritableKeyPath<TravelerProfile, String?>) -> Binding<String> {
        Binding(get: { store.draft[keyPath: path] ?? "" }, set: { store.draft[keyPath: path] = $0.isEmpty ? nil : $0 })
    }
    private func preference(_ path: WritableKeyPath<TravelerPreferences, String?>) -> Binding<String> {
        Binding(get: { store.draft.preferences[keyPath: path] ?? "" }, set: { store.draft.preferences[keyPath: path] = $0.isEmpty ? nil : $0 })
    }
    private func entries(_ label: String, values: Binding<[String]>) -> some View {
        VStack(alignment: .leading) {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            TextField("Optional; one entry per line", text: Binding(get: { values.wrappedValue.joined(separator: "\n") }, set: { values.wrappedValue = $0.components(separatedBy: "\n") }), axis: .vertical)
                .lineLimit(1...4)
                .accessibilityLabel(label)
        }
    }
}
