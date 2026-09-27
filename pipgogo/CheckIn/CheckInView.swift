import SwiftUI

struct CheckInView: View {
    @Bindable var store: CheckInStore
    let companions: [APIRecord<Companion>]
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmDiscard = false

    var body: some View {
        Form {
            if store.busy { ProgressView("Updating check-in…") }
            if let error = store.errorMessage { Section { Text(error).foregroundStyle(.red) } }
            Section("Trip context") {
                if let trip = store.trip {
                    Text(trip.data.title).font(.headline)
                    Text(trip.data.dateSummary)
                    Text("Trip version \(trip.version)")
                    NavigationLink("Review full trip details") { TripSummaryView(trip: trip.data, companions: companions) }
                }
                if !store.loaded { Text("Current context has not been verified. Refresh before confirming.").foregroundStyle(.orange) }
                Button("Refresh trip and check-in") { Task { await store.load() } }
                    .disabled(store.busy).accessibilityIdentifier("checkin.refresh")
            }
            if let saved = store.saved {
                Section("Saved check-in") {
                    Text("Saved \(saved.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    Text("Confirmed trip version \(saved.data.confirmedTripVersion)")
                    Text(store.isCurrent ? "Confirmed against the latest loaded trip." : "Review and reconfirm the current trip before continuing.")
                        .foregroundStyle(store.isCurrent ? Color.secondary : Color.orange)
                }
            }
            if store.hasConflict {
                Section("Check-in changed elsewhere") {
                    Text("Compare your notes below with the saved notes. Keeping your notes requires a separate confirmation and save.")
                    Text("Saved requests: \(store.conflicting?.data.requests ?? "None")")
                    Text("Saved concerns: \(store.conflicting?.data.concerns ?? "None")")
                    Button("Keep my notes") { Task { await store.resolveConflict(useSaved: false) } }
                    Button("Use saved notes", role: .destructive) { confirmDiscard = true }
                }.disabled(store.busy)
            }
            Section("Requests and concerns (optional)") {
                TextField("Requests", text: $store.requests, axis: .vertical)
                    .lineLimit(3...8).accessibilityIdentifier("checkin.requests")
                TextField("Concerns", text: $store.concerns, axis: .vertical)
                    .lineLimit(3...8).accessibilityIdentifier("checkin.concerns")
                Text("Up to 2,000 characters each. Clear a field to remove saved notes.").font(.caption)
            }.disabled(!store.canEdit)
            Section("Travel information") {
                Text("Live travel data is unavailable. Saving a check-in records your trip confirmation and notes; it does not verify flights, weather, transport or other operational information.")
                if let refresh = store.saved?.data.refresh {
                    Text("Last refresh attempt: \(refresh.attemptedAt.formatted(date: .abbreviated, time: .shortened))")
                    ForEach(Array(refresh.warnings.enumerated()), id: \.offset) { _, warning in Text(warning) }
                    if !refresh.missingCategories.isEmpty {
                        Text("Missing: " + refresh.missingCategories.map { $0.replacingOccurrences(of: "_", with: " ") }.joined(separator: ", "))
                    }
                }
            }
            Section {
                Toggle("I have reviewed and confirm this trip context", isOn: $store.confirmed)
                    .disabled(!store.canEdit).accessibilityIdentifier("checkin.confirm")
                if store.pending != nil { Text("The save outcome is uncertain. Retry the same request before editing your notes.") }
                Button(store.pending == nil ? "Save check-in" : "Retry save") { Task { await store.save() } }
                    .disabled(!store.canSave).accessibilityIdentifier("checkin.save")
            } footer: {
                Text("Unsaved notes stay in this app session. Signing out or closing the app completely clears them. Offline storage is not available yet.")
            }
        }
        .navigationTitle("Pre-trip check-in")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: scenePhase) { if scenePhase == .active { await store.load() } }
        .confirmationDialog("Replace your notes with the saved check-in?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Use saved notes", role: .destructive) { Task { await store.resolveConflict(useSaved: true) } }
        }
    }
}
