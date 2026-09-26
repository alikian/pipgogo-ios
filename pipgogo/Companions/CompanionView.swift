import SwiftUI

struct CompanionListView: View {
    @Bindable var store: CompanionStore
    @State private var editing = false

    var body: some View {
        List {
            if let editor = store.editor, !editor.finished && !editor.canLeave {
                Section {
                    Button("Continue editing \(editor.draft.displayName)") { editing = true }
                        .disabled(store.busy)
                    Text("Save or discard this draft before editing another companion.").foregroundStyle(.secondary)
                }
            }
            if let error = store.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red)
                    Button("Try again") { Task { await store.load(refresh: true) } }.disabled(store.busy)
                }
            }
            if store.busy { ProgressView("Loading companions…") }
            if store.loaded {
                if store.items.isEmpty {
                    ContentUnavailableView("No companions yet", systemImage: "person.2", description: Text("Save the people you travel with so you can add them to future trips."))
                } else {
                    Section("Your companions") {
                        ForEach(store.items.sorted { $0.data.displayName.localizedStandardCompare($1.data.displayName) == .orderedAscending }) { record in
                            Button {
                                if store.open(record) { editing = true }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(record.data.displayName).foregroundStyle(.primary)
                                        if let relationship = record.data.relationship { Text(relationship).font(.subheadline).foregroundStyle(.secondary) }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                                }
                            }.disabled(!store.canOpenAnother && store.editor?.id.uuidString.lowercased() != record.id || store.busy)
                        }
                    }
                }
                Button { if store.open() { editing = true } } label: { Label("Add companion", systemImage: "person.badge.plus") }
                    .disabled(!store.canOpenAnother)
            }
            Section {
                Text("Companions are saved to your account. All details are optional; share only what helps plan your trips.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Companions")
        .task { await store.load() }
        .refreshable { await store.load(refresh: true) }
        .navigationDestination(isPresented: $editing) {
            if let editor = store.editor { CompanionEditorView(store: editor) }
        }
    }
}

struct CompanionEditorView: View {
    @Bindable var store: CompanionEditorStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @State private var confirmDiscard = false
    @State private var confirmSaved = false

    var body: some View {
        Form {
            if store.finished {
                Text("This companion is no longer being edited.")
                Button("Back to companions") { dismiss() }
            } else {
                if let conflict = store.conflict {
                    Section(conflict.removed ? "Companion removed elsewhere" : "Companion changed elsewhere") {
                        Text(conflict.removed ? "Your draft is safe. You can keep it as a new companion or accept the removal." : "Compare your draft with the saved companion before choosing what to keep. Nothing will be overwritten automatically.")
                        ForEach(Array(store.draft.summary.enumerated()), id: \.offset) { index, row in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.0).font(.headline)
                                Text("Your draft: \(row.1)")
                                Text("Saved: \(conflict.saved?.data.summary[index].1 ?? "Removed")").foregroundStyle(.secondary)
                            }
                        }
                        Button(conflict.removed ? "Keep as new companion" : "Keep my draft") { store.keepDraft() }
                        Button(conflict.removed ? "Accept removal" : "Use saved companion", role: .destructive) { confirmSaved = true }
                    }
                }
                Group {
                    Section("About your companion") {
                        TextField("Name or nickname", text: optional(\.nickname))
                        TextField("Relationship (optional)", text: optional(\.relationship))
                        TextField("Age range (optional)", text: optional(\.ageRange))
                    }
                    Section {
                        LanguageSelectionView(languages: $store.draft.preferences.languages)
                        entries("Interests", values: $store.draft.preferences.interests)
                        entries("Dietary needs", values: $store.draft.preferences.dietaryNeeds)
                        entries("Accessibility needs", values: $store.draft.preferences.accessibilityNeeds)
                        entries("Transportation preferences", values: $store.draft.preferences.transportation)
                    } header: { Text("Preferences") } footer: {
                        Text("For text preferences, use one entry per line, up to 30 per list. Each entry can contain up to 300 characters. Clear an entry and save to remove it.")
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
                        Text("The request has not been confirmed. Retry it before making more changes.")
                    }
                    if let notice = store.notice { Text(notice).foregroundStyle(.secondary) }
                    if store.busy { ProgressView("Saving changes…") }
                    if store.pending?.method == "DELETE" {
                        Button("Retry deletion", role: .destructive) { Task { await store.delete() } }.disabled(store.busy)
                    } else {
                        Button(store.pending == nil ? "Save companion" : "Retry save") {
                            Task { if await store.save() { dismiss() } }
                        }.disabled(!store.canSave)
                    }
                    if store.canEdit && (store.dirty || store.saved == nil) {
                        Button("Discard changes", role: .destructive) { confirmDiscard = true }
                    }
                } footer: {
                    Text("Unsaved changes stay in this app session. They are cleared when you sign out or close the app completely.")
                }
                if store.saved != nil && store.pending?.method != "DELETE" {
                    Section {
                        Button("Delete companion", role: .destructive) { confirmDelete = true }.disabled(!store.canDelete)
                    } footer: {
                        Text("Save or discard edits before deleting. A companion used in an active trip cannot be deleted. Historical trip packages may still contain their details.")
                    }
                }
            }
        }
        .navigationTitle(store.saved == nil ? "New companion" : "Edit companion")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: store.finished) { _, finished in if finished { dismiss() } }
        .confirmationDialog("Delete this companion?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete companion", role: .destructive) { Task { await store.delete() } }
        } message: { Text("This removes them from your companion list. Historical packages may retain their details.") }
        .confirmationDialog("Discard your unsaved changes?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard changes", role: .destructive) { store.discardChanges() }
        }
        .confirmationDialog("Discard your draft and use the server's saved state?", isPresented: $confirmSaved, titleVisibility: .visible) {
            Button("Use saved state", role: .destructive) { store.useSaved() }
        }
    }

    private func optional(_ path: WritableKeyPath<Companion, String?>) -> Binding<String> {
        Binding(get: { store.draft[keyPath: path] ?? "" }, set: { store.draft[keyPath: path] = $0.isEmpty ? nil : $0 })
    }
    private func preference(_ path: WritableKeyPath<TravelerPreferences, String?>) -> Binding<String> {
        Binding(get: { store.draft.preferences[keyPath: path] ?? "" }, set: { store.draft.preferences[keyPath: path] = $0.isEmpty ? nil : $0 })
    }
    private func entries(_ label: String, values: Binding<[String]>) -> some View {
        VStack(alignment: .leading) {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            TextField("Optional; one entry per line", text: Binding(get: { values.wrappedValue.joined(separator: "\n") }, set: { values.wrappedValue = $0.components(separatedBy: "\n") }), axis: .vertical)
                .lineLimit(1...4).accessibilityLabel(label)
        }
    }
}
