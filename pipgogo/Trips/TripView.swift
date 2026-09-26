import SwiftUI

struct TripListView: View {
    @Bindable var store: TripStore
    let companions: CompanionStore
    @State private var creating = false

    var body: some View {
        List {
            if store.busy { ProgressView("Loading trips…") }
            if let error = store.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red)
                    Button("Try again") { Task { await store.load(refresh: true) } }.disabled(store.busy)
                }
            }
            if store.loaded {
                if store.items.isEmpty {
                    ContentUnavailableView("No trips yet", systemImage: "suitcase.rolling", description: Text("Start with a destination. You can leave dates and accommodation open for now."))
                }
                ForEach(store.items.sorted { $0.updatedAt > $1.updatedAt }) { trip in
                    NavigationLink {
                        TripDetailView(store: store, companions: companions, id: trip.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(trip.data.title).font(.headline)
                            Text(trip.data.dateSummary).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }.disabled(store.busy)
                }
                Button {
                    if store.beginCreation() { creating = true }
                } label: {
                    Label(store.hasDraft ? "Continue trip draft" : "Create trip", systemImage: store.hasDraft ? "square.and.pencil" : "plus")
                }.disabled(store.busy)
            }
        }
        .navigationTitle("Trips")
        .task { await store.load() }
        .refreshable { await store.load(refresh: true) }
        .navigationDestination(isPresented: $creating) {
            TripEditorView(store: store, companions: companions)
        }
    }
}

struct TripEditorView: View {
    @Bindable var store: TripStore
    @Bindable var companions: CompanionStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDiscard = false
    @State private var confirmExisting = false
    @State private var confirmDelete = false

    var body: some View {
        Form {
            if let conflict = store.conflict {
                Section("Trip already changed") {
                    Text("Your draft is kept. Compare it with the saved trip before choosing how to continue. Nothing is overwritten automatically.")
                    NavigationLink("Review your draft") { TripSummaryView(trip: store.draft, companions: companions.items) }
                    if let existing = conflict.existing {
                        NavigationLink("Review existing trip") { TripSummaryView(trip: existing.data, companions: companions.items) }
                    }
                    if store.isEditing && conflict.existing != nil {
                        Button("Keep my draft") { store.keepDraft() }
                        Text("Keeping your draft does not save it. Review your changes, then save against the updated trip.").font(.caption)
                    } else {
                        Button("Keep draft as a separate trip") { store.keepAsNewTrip() }
                    }
                    Button(conflict.existing == nil ? "Discard draft" : "Use existing trip", role: .destructive) { confirmExisting = true }
                }
            }
            Group {
                Section {
                    TextField("For example, Japan", text: Binding(get: { store.draft.destinations.joined(separator: "\n") }, set: { store.draft.destinations = $0.components(separatedBy: "\n") }), axis: .vertical)
                        .lineLimit(1...5).accessibilityLabel("Destinations")
                } header: { Text("Destinations") } footer: { Text("Enter 1–10 destinations in travel order, one per line.") }
                Section("Dates (optional)") {
                    dateField("Start date", path: \.startDate)
                    dateField("End date", path: \.endDate)
                }
                Section("Accommodation (optional)") {
                    TextField("Name", text: lodging(\.name))
                    TextField("Address", text: lodging(\.address), axis: .vertical)
                    TextField("Arrival instructions", text: lodging(\.instructions), axis: .vertical).lineLimit(2...5)
                    TextField("Reservation reference", text: lodging(\.reservationReference))
                    if store.draft.accommodation != nil {
                        Button("Clear accommodation", role: .destructive) { store.draft.accommodation = nil }
                    }
                }
                Section {
                    if companions.busy { ProgressView("Loading companions…") }
                    if let error = companions.errorMessage { Text(error).foregroundStyle(.red) }
                    Button(companions.errorMessage == nil ? "Refresh companions" : "Retry loading companions") {
                        Task { await companions.load(refresh: true) }
                    }.disabled(companions.busy)
                    if companions.loaded && companions.items.isEmpty { Text("No saved companions. You can add them from your account's Companions screen.").foregroundStyle(.secondary) }
                    ForEach(companions.items) { companion in
                        Toggle(companion.data.displayName, isOn: selected(companion.id))
                            .disabled(companions.busy || (store.draft.companionIDs.count >= 20 && !store.draft.companionIDs.contains(companion.id)))
                    }
                    ForEach(store.draft.companionIDs.filter { id in !companions.items.contains { $0.id == id } }, id: \.self) { id in
                        Toggle("Previously selected companion (unavailable)", isOn: selected(id))
                    }
                } header: { Text("Companions (optional)") } footer: {
                    Text("Choose up to 20 saved companions for this trip. Leave this empty if you are traveling alone or have not decided yet.")
                }
                Section("Plans and needs (optional)") {
                    TextField("Transportation plan", text: optional(\.transportationPlan), axis: .vertical).lineLimit(2...5)
                    entries("Itinerary", values: $store.draft.itinerary)
                    entries("Constraints or things to keep in mind", values: $store.draft.constraints)
                }
                Section("Trip preferences (optional)") {
                    LanguageSelectionView(languages: $store.draft.preferences.languages)
                    entries("Interests", values: $store.draft.preferences.interests)
                    entries("Dietary needs", values: $store.draft.preferences.dietaryNeeds)
                    entries("Accessibility needs", values: $store.draft.preferences.accessibilityNeeds)
                    entries("Transportation preferences", values: $store.draft.preferences.transportation)
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
                if let error = store.saveError { Text(error).foregroundStyle(.red) }
                if (store.pending != nil || store.pendingDeletion != nil) && !store.busy {
                    Text("The request has not been confirmed. Retry it before changing this draft.")
                }
                if store.pendingDeletion != nil {
                    Button("Retry deletion", role: .destructive) {
                        Task { if await store.delete() { dismiss() } }
                    }.disabled(store.busy)
                }
                Button {
                    Task { if await store.save() { dismiss() } }
                } label: {
                    HStack {
                        Text(store.pending == nil ? "Save trip" : "Retry save")
                        if store.busy { Spacer(); ProgressView() }
                    }
                }.disabled(!store.canSave)
                Button("Discard draft", role: .destructive) { confirmDiscard = true }.disabled(!store.canEdit)
            } footer: { Text("Unsaved changes stay in this app session. They are cleared when you sign out or close the app completely.") }
            if store.isEditing {
                Section {
                    Button("Delete trip", role: .destructive) { confirmDelete = true }.disabled(!store.canDelete)
                } footer: {
                    Text("Save or discard edits before deleting. Deletion removes the trip from your active list. Historical packages and answers remain in your account until account deletion; this is not permanent erasure.")
                }
            }
        }
        .navigationTitle(store.isEditing ? "Edit trip" : "New trip")
        .navigationBarTitleDisplayMode(.inline)
        .task { await companions.load(refresh: true) }
        .confirmationDialog("Delete this trip?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete trip", role: .destructive) { Task { if await store.delete() { dismiss() } } }
        } message: { Text("This removes the trip from your active list. Historical packages and answers remain until account deletion.") }
        .confirmationDialog("Discard this trip draft?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard draft", role: .destructive) { store.discardDraft(); dismiss() }
        }
        .confirmationDialog("Discard your draft and use the existing saved state?", isPresented: $confirmExisting, titleVisibility: .visible) {
            Button("Use saved state", role: .destructive) { store.useExistingTrip(); dismiss() }
        }
    }

    private func optional(_ path: WritableKeyPath<Trip, String?>) -> Binding<String> {
        Binding(get: { store.draft[keyPath: path] ?? "" }, set: { store.draft[keyPath: path] = $0.isEmpty ? nil : $0 })
    }
    private func preference(_ path: WritableKeyPath<TravelerPreferences, String?>) -> Binding<String> {
        Binding(get: { store.draft.preferences[keyPath: path] ?? "" }, set: { store.draft.preferences[keyPath: path] = $0.isEmpty ? nil : $0 })
    }
    private func entries(_ label: String, values: Binding<[String]>) -> some View {
        VStack(alignment: .leading) {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            TextField("One entry per line", text: Binding(get: { values.wrappedValue.joined(separator: "\n") }, set: { values.wrappedValue = $0.components(separatedBy: "\n") }), axis: .vertical)
                .lineLimit(1...5).accessibilityLabel(label)
        }
    }

    private func selected(_ id: String) -> Binding<Bool> {
        Binding(get: { store.draft.companionIDs.contains(id) }, set: { selected in
            if selected && !store.draft.companionIDs.contains(id) { store.draft.companionIDs.append(id) }
            if !selected { store.draft.companionIDs.removeAll { $0 == id } }
        })
    }
    private func lodging(_ path: WritableKeyPath<TripAccommodation, String?>) -> Binding<String> {
        Binding(get: { store.draft.accommodation?[keyPath: path] ?? "" }, set: { value in
            var accommodation = store.draft.accommodation ?? TripAccommodation()
            accommodation[keyPath: path] = value.isEmpty ? nil : value
            store.draft.accommodation = accommodation
        })
    }
    @ViewBuilder private func dateField(_ label: String, path: WritableKeyPath<Trip, String?>) -> some View {
        Toggle("Set \(label.lowercased())", isOn: Binding(get: { store.draft[keyPath: path] != nil }, set: { store.draft[keyPath: path] = $0 ? TripDates.string(.now) : nil }))
        if store.draft[keyPath: path] != nil {
            DatePicker(label, selection: Binding(get: { store.draft[keyPath: path].flatMap(TripDates.date) ?? .now }, set: { store.draft[keyPath: path] = TripDates.string($0) }), displayedComponents: .date)
                .environment(\.calendar, Calendar(identifier: .gregorian))
        }
    }
}

struct TripDetailView: View {
    @Bindable var store: TripStore
    @Bindable var companions: CompanionStore
    let id: String
    @State private var editing = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let record = store.items.first(where: { $0.id == id }) {
                TripSummaryView(trip: record.data, companions: companions.items, error: store.errorMessage, busy: store.busy)
            } else {
                ContentUnavailableView("Trip unavailable", systemImage: "suitcase", description: Text(store.errorMessage ?? "This trip may have been removed."))
            }
        }
        .navigationTitle("Trip details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editing, onDismiss: {
            if !store.items.contains(where: { $0.id == id }) { dismiss() }
        }) {
            NavigationStack {
                TripEditorView(store: store, companions: companions)
                    .toolbar { Button("Back to trip") { editing = false } }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if store.hasDraft && store.draftID.uuidString.lowercased() != id {
                Text("Finish or discard your other trip draft from the Trips list before editing this trip.")
                    .font(.caption).padding().background(.regularMaterial)
            }
        }
        .toolbar {
            Button("Edit") { if store.beginEditing(id) { editing = true } }
                .disabled(store.busy || !store.items.contains(where: { $0.id == id }) || (store.hasDraft && store.draftID.uuidString.lowercased() != id))
        }
        .task(id: scenePhase == .active && !editing) {
            guard scenePhase == .active, !editing, store.items.contains(where: { $0.id == id }) else { return }
            await store.refreshTrip(id)
            guard !Task.isCancelled else { return }
            await companions.load(refresh: true)
        }
    }
}

struct TripSummaryView: View {
    let trip: Trip
    let companions: [APIRecord<Companion>]
    var error: String? = nil
    var busy = false

    var body: some View {
        List {
            if busy { ProgressView("Refreshing trip…") }
            if let error { Text("Could not refresh: \(error) Showing the last loaded trip.").foregroundStyle(.red) }
            Section("Your trip") {
                Text(trip.title).font(.headline)
                Text(trip.dateSummary)
            }
            if let lodging = trip.accommodation {
                Section("Accommodation") {
                    row("Name", lodging.name)
                    row("Address", lodging.address)
                    row("Check-in", lodging.checkIn)
                    row("Arrival instructions", lodging.instructions)
                    row("Reservation reference", lodging.reservationReference)
                }
            }
            Section("Companions") {
                if trip.companionIDs.isEmpty { Text("No companions selected").foregroundStyle(.secondary) }
                ForEach(Array(trip.companionIDs.enumerated()), id: \.element) { index, id in
                    Text(companions.first { $0.id == id }?.data.displayName ?? "Saved companion \(index + 1) (name unavailable)")
                }
            }
            if let flight = trip.arrival { flightSection("Arrival flight", flight: flight) }
            if let flight = trip.departure { flightSection("Departure flight", flight: flight) }
            if !trip.itinerary.isEmpty {
                Section("Itinerary") { ForEach(Array(trip.itinerary.enumerated()), id: \.offset) { _, item in Text(item) } }
            }
            if let plan = trip.transportationPlan { Section("Transportation") { Text(plan) } }
            if !trip.constraints.isEmpty {
                Section("Things to keep in mind") { ForEach(Array(trip.constraints.enumerated()), id: \.offset) { _, item in Text(item) } }
            }
            if trip.preferences != TravelerPreferences() {
                Section("Trip preferences") {
                    ForEach(Array(TravelerProfile(preferences: trip.preferences).summary.dropFirst(4).enumerated()), id: \.offset) { _, item in
                        LabeledContent(item.0, value: item.1)
                    }
                }
            }
            if let amount = trip.budgetMinor, let currency = trip.currency {
                Section("Budget") { Text(budget(amount, currency: currency)) }
            }
        }
    }

    @ViewBuilder private func row(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty { LabeledContent(label, value: value) }
    }
    private func flightSection(_ label: String, flight: TripFlight) -> some View {
        Section(label) {
            row("Flight", flight.number)
            row("Airport", flight.airport)
            row("Scheduled", flight.scheduledAt)
        }
    }
    private func budget(_ minor: Int, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        let scale = NSDecimalNumber(mantissa: 1, exponent: Int16(formatter.maximumFractionDigits), isNegative: false)
        let amount = NSDecimalNumber(value: minor).dividing(by: scale)
        return formatter.string(from: amount) ?? "\(currency) \(amount)"
    }
}
