import SwiftUI
import Observation

struct OrganizerPerson: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var name = ""
    var age: Int? = nil
    var hometown = ""
    var interests = ""
    var notes = ""
}
struct OrganizerStop: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var destination = ""
    var arrival: String? = nil
    var departure: String? = nil
    var hotel = ""
    var hotel_address = ""
    var check_in: String? = nil
    var check_out: String? = nil
    // Travel from the preceding stop to this destination.
    var transport = ""
    var transport_details = ""
}
struct OrganizerParty: Codable, Equatable, Sendable {
    var adults: Int
    var children: Int
    var total: Int { adults + children }
    // Only recover explicitly labeled counts from older chat drafts, never infer from names.
    static func legacyNotes(_ notes: String) -> OrganizerParty? {
        let pattern = #"(?i)^Travelers: (\d+) adults? and (one|\d+) (\d+)-year-old(?:;|[ .])"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: notes, range: NSRange(notes.startIndex..., in: notes)),
              let adultsRange = Range(match.range(at: 1), in: notes),
              let countRange = Range(match.range(at: 2), in: notes),
              let ageRange = Range(match.range(at: 3), in: notes),
              let adults = Int(notes[adultsRange]), let age = Int(notes[ageRange]), age < 18,
              let children = notes[countRange].lowercased() == "one" ? 1 : Int(notes[countRange]),
              adults + children > 0, adults + children <= 30 else { return nil }
        return OrganizerParty(adults: adults, children: children)
    }
}
struct OrganizerTrip: Codable, Equatable, Identifiable, Sendable {
    var party: OrganizerParty? = nil
    var budget: OrganizerBudget? = nil
    var id = UUID()
    var name = ""
    var include_me = true
    var companion_ids: [UUID] = []
    var stops: [OrganizerStop] = []
    var notes = ""
}
// Navigation transitions can keep a child alive after its stop is removed or reordered.
// Resolve by identity on every access; a stale child must never edit a different stop.
extension Binding where Value == OrganizerTrip {
    func stop(_ snapshot: OrganizerStop) -> Binding<OrganizerStop> {
        Binding<OrganizerStop>(
            get: { wrappedValue.stops.first { $0.id == snapshot.id } ?? snapshot },
            set: { updated in
                guard let index = wrappedValue.stops.firstIndex(where: { $0.id == snapshot.id }) else { return }
                wrappedValue.stops[index] = updated
            }
        )
    }
}

struct OrganizerData: Codable, Equatable, Sendable {
    var profile: OrganizerPerson? = nil
    var companions: [OrganizerPerson] = []
    var trips: [OrganizerTrip] = []
}

@MainActor @Observable
final class OrganizerStore {
    var data = OrganizerData()
    var version = 0
    var loaded = false
    var busy = false
    var error: String?
    var conflict: APIRecord<OrganizerData>?
    private(set) var pending: APIRequest<APIRecord<OrganizerData>>?
    private var epoch = UUID()
    private let client: APIClient
    private let authentication: any AccessTokenProviding
    init(client: APIClient, authentication: any AccessTokenProviding) {
        self.client = client; self.authentication = authentication
    }
    func reset() {
        epoch = UUID(); data = OrganizerData(); version = 0; loaded = false
        busy = false; error = nil; conflict = nil; pending = nil
    }
    func load() async {
        guard !busy, pending == nil else { return }
        busy = true; let ticket = epoch
        defer { if ticket == epoch { busy = false } }
        do {
            let result: APIRecord<OrganizerData> = try await client.send(.get(.organizer), using: authentication)
            guard ticket == epoch else { return }
            data = result.data; version = result.version; loaded = true; error = nil
        } catch { if ticket == epoch { self.error = error.localizedDescription } }
    }
    func save(_ draft: OrganizerData) async -> Bool {
        guard loaded, !busy, pending == nil else { return false }
        do { pending = try .put(.organizer, body: draft, expectedVersion: version) }
        catch { self.error = error.localizedDescription; return false }
        return await retry()
    }
    func retry() async -> Bool {
        guard !busy, conflict == nil, let request = pending else { return false }
        busy = true; let ticket = epoch
        defer { if ticket == epoch { busy = false } }
        do {
            _ = try await client.send(request, using: authentication)
            guard ticket == epoch else { return false }
            let current: APIRecord<OrganizerData> = try await client.send(.get(.organizer), using: authentication)
            guard ticket == epoch else { return false }
            data = current.data; version = current.version; pending = nil; error = nil
            return true
        } catch APIClientError.conflict(let body, _) {
            guard ticket == epoch else { return false }
            if let record = body.currentRecord, let decoded = try? record.data.decoded(as: OrganizerData.self) {
                conflict = APIRecord(id: record.id, kind: record.kind, version: record.version, revision: record.revision, updatedAt: record.updatedAt, deleted: record.deleted, data: decoded)
            }
            error = body.message
        } catch APIClientError.rejected(let status, let body, _) {
            guard ticket == epoch else { return false }
            error = body.message
            if [400, 403, 404, 413, 422].contains(status) { pending = nil }
        } catch { if ticket == epoch { self.error = error.localizedDescription } }
        return false
    }
    func useLatest() {
        guard let conflict else { return }
        data = conflict.data; version = conflict.version; self.conflict = nil; pending = nil; error = nil
    }
}

struct TravelOrganizerView: View {
    @Bindable var store: OrganizerStore
    let chat: TravelChatStore
    @State private var showChat = false
    @State private var showVoice = false
    var profilePictureURL: URL? = nil
    let signOut: () -> Void
    @State private var editor: OrganizerEditorKind?
    private var companionSummary: String {
        let companions = store.data.companions
        guard !companions.isEmpty else { return "Add travel companions" }
        let names = companions.prefix(3).map(\.name).joined(separator: ", ")
        return companions.count > 3 ? "\(names) +\(companions.count - 3)" : names
    }
    var body: some View {
        NavigationStack {
            List {
                if let error = store.error {
                    Section { Text(error).foregroundStyle(.red)
                        if !store.loaded { Button("Try again") { Task { await store.load() } } }
                    }
                }
                if store.busy { ProgressView() }
                if store.loaded {
                    Section("My Profile") {
                        Button { editor = .profile } label: {
                            HStack(spacing: 12) {
                                AsyncImage(url: profilePictureURL) { phase in
                                    if let image = phase.image { image.resizable().scaledToFill() }
                                    else { Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().foregroundStyle(.secondary) }
                                }
                                .frame(width: 52, height: 52)
                                .clipShape(Circle())
                                .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(store.data.profile?.name ?? "Add your profile")
                                    Label(companionSummary, systemImage: "person.2")
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Section {
                        Button("Ask Pip", systemImage: "bubble.left.and.bubble.right") { showChat = true }
                        Button("Talk to Pip", systemImage: "mic.fill") { showVoice = true }
                            .disabled(chat.busy || chat.pending != nil)
                    }
                    Section("Trips") {
                        ForEach(store.data.trips) { trip in
                            Button { editor = .trip(trip.id) } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(trip.name).font(.headline)
                                    Text(trip.stops.isEmpty ? "Add destinations when you're ready" : trip.stops.map(\.destination).joined(separator: " → "))
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                        Button("Add trip", systemImage: "plus") { editor = .trip(UUID()) }
                    }
                }
            }
            .refreshable { await store.load() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Text("PipPipGo").font(.headline) }
                ToolbarItem(placement: .topBarTrailing) { Button("Sign out", action: signOut) }
            }
            .task { if !store.loaded { await store.load() } }
            .sheet(item: $editor) { kind in OrganizerEditor(store: store, kind: kind) }
            .sheet(isPresented: $showChat) { TravelChatView(store: chat, organizer: store, name: store.data.profile?.name) }
            .sheet(isPresented: $showVoice) { VoiceConversationSheet(store: chat.voice) }
        }
    }
}
enum OrganizerEditorKind: Identifiable {
    case profile, person(UUID), trip(UUID)
    var id: String {
        switch self { case .profile: "profile"; case .person(let id): "person-\(id)"; case .trip(let id): "trip-\(id)" }
    }
}
struct OrganizerEditor: View {
    @Bindable var store: OrganizerStore
    let kind: OrganizerEditorKind
    @Environment(\.dismiss) private var dismiss
    @State private var person = OrganizerPerson()
    @State private var trip = OrganizerTrip()
    private let initialTrip: OrganizerTrip?
    private let onSaved: (UUID) -> Void
    @State private var companionEditor: OrganizerEditorKind?
    @State private var editingStop: OrganizerStop?
    @State private var confirmDelete = false
    init(store: OrganizerStore, kind: OrganizerEditorKind, initialTrip: OrganizerTrip? = nil, onSaved: @escaping (UUID) -> Void = { _ in }) {
        self.store = store
        self.kind = kind
        self.initialTrip = initialTrip
        self.onSaved = onSaved
        // State is initialized once for this sheet, not whenever the parent reappears.
        switch kind {
        case .profile:
            _person = State(initialValue: store.data.profile ?? OrganizerPerson())
        case .person(let id):
            _person = State(initialValue: store.data.companions.first { $0.id == id } ?? OrganizerPerson(id: id))
        case .trip(let id):
            var draft = store.data.trips.first { $0.id == id } ?? initialTrip ?? OrganizerTrip(id: id)
            if draft.party == nil { draft.party = OrganizerParty.legacyNotes(draft.notes) }
            _trip = State(initialValue: draft)
        }
    }
    private var isTrip: Bool { if case .trip = kind { true } else { false } }
    private var isProfile: Bool { if case .profile = kind { true } else { false } }
    private var exists: Bool {
        isTrip ? store.data.trips.contains { $0.id == trip.id } : !isProfile && store.data.companions.contains { $0.id == person.id }
    }
    var body: some View {
        NavigationStack {
            Form {
                Group {
                    if isTrip { tripFields } else { personFields }
                    if exists { Button("Delete", role: .destructive) { confirmDelete = true } }
                }.disabled(store.busy || store.pending != nil)
                if let error = store.error { Section { Text(error).foregroundStyle(.red) } }
                if let conflict = store.conflict {
                    Section("Review changes from another device") {
                        Text("Your edit has not overwritten the saved version. Reload the latest version to review and edit it.")
                        Text("Saved trips: \(conflict.data.trips.map(\.name).joined(separator: ", "))")
                        Button("Discard this edit and load latest") { store.useLatest(); loadDraft() }
                    }
                } else if store.pending != nil {
                    Button("Retry same save") { Task { if await store.retry() { onSaved(isTrip ? trip.id : person.id); dismiss() } } }.disabled(store.busy)
                }
            }
            .navigationDestination(item: $editingStop) { stop in
                OrganizerStopEditor(stop: $trip.stop(stop), previous: previousStop(stop.id))
            }
            .navigationTitle(isTrip ? "Trip" : isProfile ? "My Profile" : "Companion")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(store.pending != nil || store.busy) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save(deleting: false) } }
                        .disabled(store.busy || store.pending != nil || (isTrip ? trip.name : person.name).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(item: $companionEditor) { kind in
                OrganizerEditor(store: store, kind: kind) { id in
                    if isTrip, store.data.companions.contains(where: { $0.id == id }), !trip.companion_ids.contains(id) {
                        trip.companion_ids.append(id)
                    }
                }
            }
            .interactiveDismissDisabled(store.pending != nil || store.busy)
            .confirmationDialog("Delete this \(isTrip ? "trip" : "companion")?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) { Task { await save(deleting: true) } }
            }
        }
    }
    private var personFields: some View {
        Group {
            Section("Details") {
                TextField("Name", text: $person.name)
                TextField("Age (optional)", value: $person.age, format: .number).keyboardType(.numberPad)
                TextField("Home town", text: $person.hometown)
            }
            Section("Optional") {
                TextField("Interests", text: $person.interests, axis: .vertical)
                TextField("Important notes, dietary or accessibility needs", text: $person.notes, axis: .vertical)
            }
            if isProfile {
                Section("Travel companions") {
                    ForEach(store.data.companions) { companion in
                        Button { companionEditor = .person(companion.id) } label: {
                            HStack {
                                Text(companion.name)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Button("Add companion", systemImage: "person.badge.plus") { companionEditor = .person(UUID()) }
                }
            }
        }
    }
    private var tripFields: some View {
        Group {
            Section { TextField("Trip name", text: $trip.name) }
            Section("Who is traveling?") {
                if let party = trip.party {
                    Text("\(party.adults) adults · \(party.children) children · \(party.total) travelers total").font(.headline)
                    Stepper("Adults: \(party.adults)", value: Binding(get: { trip.party?.adults ?? 0 }, set: { trip.party?.adults = $0 }), in: 0...30)
                    Stepper("Children: \(party.children)", value: Binding(get: { trip.party?.children ?? 0 }, set: { trip.party?.children = $0 }), in: 0...30)
                    let unnamed = max(0, party.total - trip.companion_ids.count - (trip.include_me ? 1 : 0))
                    if unnamed > 0 { Text("\(unnamed) travelers without names assigned").foregroundStyle(.secondary) }
                    Text("Party size includes you and everyone selected below. Names are optional; selecting someone does not add to the total.").font(.caption).foregroundStyle(.secondary)
                } else {
                    Button("Set party size") { trip.party = OrganizerParty(adults: max(1, trip.companion_ids.count + (trip.include_me ? 1 : 0)), children: 0) }
                }
                Toggle("Me", isOn: $trip.include_me)
                ForEach(store.data.companions) { companion in
                    Toggle(companion.name, isOn: Binding(get: { trip.companion_ids.contains(companion.id) }, set: { selected in
                        trip.companion_ids.removeAll { $0 == companion.id }
                        if selected { trip.companion_ids.append(companion.id) }
                    }))
                }
                Button("Add someone", systemImage: "person.badge.plus") { companionEditor = .person(UUID()) }
            }
            Section("Destinations · in travel order") {
                ForEach(trip.stops) { stop in
                    HStack(spacing: 8) {
                        Button { editingStop = stop } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(stop.destination.isEmpty ? "New destination" : stop.destination)
                                    if !stop.hotel.isEmpty { Text(stop.hotel).font(.caption).foregroundStyle(.secondary) }
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            trip.stops.removeAll { $0.id == stop.id }
                        }
                    }
                    .contextMenu {
                        Button("Move earlier", systemImage: "arrow.up") { moveStop(stop.id, by: -1) }
                            .disabled(trip.stops.first?.id == stop.id)
                        Button("Move later", systemImage: "arrow.down") { moveStop(stop.id, by: 1) }
                            .disabled(trip.stops.last?.id == stop.id)
                    }
                }
                Button("Add destination", systemImage: "plus") {
                    let stop = OrganizerStop()
                    trip.stops.append(stop)
                    editingStop = stop
                }
                Text("Travel details belong to the destination you're arriving at. Review them after reordering stops.").font(.caption).foregroundStyle(.secondary)
            }
            Section {
                NavigationLink {
                    OrganizerBudgetView(budget: Binding(get: { trip.budget ?? OrganizerBudget() }, set: { trip.budget = $0 }))
                } label: {
                    HStack {
                        Label("Budget & costs", systemImage: "creditcard")
                        Spacer()
                        if let budget = trip.budget, let total = OrganizerBudget.amount(budget.total) {
                            Text(budget.formatted(total)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section { TextField("Trip notes", text: $trip.notes, axis: .vertical) }
        }
    }
    private func moveStop(_ id: UUID, by offset: Int) {
        guard let index = trip.stops.firstIndex(where: { $0.id == id }),
              trip.stops.indices.contains(index + offset) else { return }
        trip.stops.swapAt(index, index + offset)
    }
    private func previousStop(_ id: UUID) -> String? {
        guard let index = trip.stops.firstIndex(where: { $0.id == id }), index > 0 else { return nil }
        return trip.stops[index - 1].destination
    }
    private func loadDraft() {
        switch kind {
        case .profile: person = store.data.profile ?? OrganizerPerson()
        case .person(let id): person = store.data.companions.first { $0.id == id } ?? OrganizerPerson(id: id)
        case .trip(let id): trip = store.data.trips.first { $0.id == id } ?? initialTrip ?? OrganizerTrip(id: id)
        }
    }
    private func save(deleting: Bool) async {
        if !deleting, isTrip, let party = trip.party,
           (party.total < 1 || party.total > 30 || trip.companion_ids.count + (trip.include_me ? 1 : 0) > party.total) {
            store.error = "Check the party size: use 1–30 travelers, with enough places for everyone selected."; return
        }
        if !deleting, isTrip, let budget = trip.budget, !budget.isValid {
            store.error = "Check Budget & costs: enter positive numbers or zero, with up to two decimal places (whole amounts for JPY)."; return
        }
        var draft = store.data
        switch kind {
        case .profile: draft.profile = person
        case .person:
            if deleting && draft.trips.contains(where: { $0.companion_ids.contains(person.id) }) {
                store.error = "Remove this companion from their trips before deleting them."; return
            }
            draft.companions.removeAll { $0.id == person.id }
            if !deleting { draft.companions.append(person) }
        case .trip:
            draft.trips.removeAll { $0.id == trip.id }
            if !deleting { draft.trips.append(trip) }
        }
        if await store.save(draft) { onSaved(isTrip ? trip.id : person.id); dismiss() }
    }
}
struct OrganizerStopEditor: View {
    @Binding var stop: OrganizerStop
    var previous: String?
    var body: some View {
        Form {
            Section("Destination") {
                TextField("City or destination", text: $stop.destination)
                OptionalOrganizerDate(title: "Arrival", value: $stop.arrival)
                OptionalOrganizerDate(title: "Departure", value: $stop.departure)
            }
            Section("Hotel stay (optional)") {
                TextField("Hotel name", text: $stop.hotel)
                TextField("Address", text: $stop.hotel_address, axis: .vertical)
                OptionalOrganizerDate(title: "Check-in", value: $stop.check_in)
                OptionalOrganizerDate(title: "Check-out", value: $stop.check_out)
            }
            Section(previous.map { "Travel from \($0)" } ?? "Travel to first destination (optional)") {
                Picker("Transport", selection: $stop.transport) {
                    Text("Not decided").tag(""); Text("Plane").tag("plane")
                    Text("Train").tag("train"); Text("Car").tag("car")
                }
                TextField("Flight/train number, departure time or driving notes", text: $stop.transport_details, axis: .vertical)
            }
        }.navigationTitle("Destination")
    }
}
struct OptionalOrganizerDate: View {
    let title: String
    @Binding var value: String?
    private static var formatter: DateFormatter {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian); formatter.dateFormat = "yyyy-MM-dd"; return formatter
    }
    var body: some View {
        Toggle(title, isOn: Binding(get: { value != nil }, set: { value = $0 ? Self.formatter.string(from: Date()) : nil }))
        if value != nil {
            DatePicker(title, selection: Binding(get: { Self.formatter.date(from: value ?? "") ?? Date() }, set: { value = Self.formatter.string(from: $0) }), displayedComponents: .date)
        }
    }
}

struct TravelChatMessage: Codable, Identifiable, Sendable {
    var id: String
    var role: String
    var text: String
    var trip_draft: OrganizerTrip? = nil
}
struct TravelChatData: Codable, Sendable { var messages: [TravelChatMessage] = [] }
struct TravelChatRequest: Codable, Sendable { var text: String }

@MainActor @Observable
final class TravelChatStore {
    let voice: LiveVoiceStore
    var messages: [TravelChatMessage] = []
    var composer = ""
    var version = 0
    var loaded = false
    var busy = false
    var error: String?
    var conflict: APIRecord<TravelChatData>?
    private(set) var pending: APIRequest<APIRecord<TravelChatData>>?
    private var epoch = UUID()
    private let client: APIClient
    private let authentication: any AccessTokenProviding
    init(client: APIClient, authentication: any AccessTokenProviding) {
        self.client = client; self.authentication = authentication
        self.voice = LiveVoiceStore(client: client, authentication: authentication)
    }
    func reset() {
        voice.stop(clearCaptions: true)
        epoch = UUID(); messages = []; composer = ""; version = 0; loaded = false
        busy = false; error = nil; conflict = nil; pending = nil
    }
    func load() async {
        guard !busy, pending == nil else { return }
        busy = true; let ticket = epoch
        defer { if ticket == epoch { busy = false } }
        do {
            let result: APIRecord<TravelChatData> = try await client.send(.get(.travelChat), using: authentication)
            guard ticket == epoch else { return }
            messages = result.data.messages; version = result.version; loaded = true; error = nil
        } catch { if ticket == epoch { self.error = error.localizedDescription } }
    }
    func send() async {
        guard loaded, !busy, !voice.active, pending == nil, !composer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            pending = try .put(.travelChat, body: TravelChatRequest(text: composer), expectedVersion: version)
            await retry()
        } catch { self.error = error.localizedDescription }
    }
    func retry() async {
        guard !busy, !voice.active, conflict == nil, let request = pending else { return }
        busy = true; let ticket = epoch
        defer { if ticket == epoch { busy = false } }
        do {
            _ = try await client.send(request, using: authentication)
            guard ticket == epoch else { return }
            let current: APIRecord<TravelChatData> = try await client.send(.get(.travelChat), using: authentication)
            guard ticket == epoch else { return }
            messages = current.data.messages; version = current.version; pending = nil; composer = ""; error = nil
        } catch APIClientError.conflict(let body, _) {
            guard ticket == epoch else { return }
            if let record = body.currentRecord, let data = try? record.data.decoded(as: TravelChatData.self) {
                conflict = APIRecord(id: record.id, kind: record.kind, version: record.version, revision: record.revision, updatedAt: record.updatedAt, deleted: record.deleted, data: data)
            }
            error = body.message
        } catch APIClientError.rejected(let status, let body, _) {
            guard ticket == epoch else { return }
            error = body.message
            if [400, 403, 404, 413, 422, 429].contains(status) { pending = nil }
        } catch { if ticket == epoch { self.error = error.localizedDescription } }
    }
    func useLatest() {
        guard let conflict else { return }
        messages = conflict.data.messages; version = conflict.version
        self.conflict = nil; pending = nil; error = nil
    }
}

struct TravelChatView: View {
    @Bindable var store: TravelChatStore
    @Bindable var organizer: OrganizerStore
    @State private var reviewingTrip: OrganizerTrip?
    @State private var savedTripName: String?
    @State private var showVoice = false
    var name: String? = nil
    @Environment(\.dismiss) private var dismiss
    private let suggestions = [
        "Plan a 3-day trip to New York next weekend.",
        "Where is the nearest luggage locker?",
        "What is a good Mediterranean restaurant nearby?"
    ]
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { scroll in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("\(name.map { "Hi, \($0)!" } ?? "Hi!") I'm Pip, your travel companion. How can I help with your trip?").font(.headline)
                            if store.messages.isEmpty {
                                ForEach(suggestions, id: \.self) { suggestion in
                                    Button { store.composer = suggestion } label: {
                                        Text(suggestion).frame(maxWidth: .infinity, alignment: .leading)
                                    }.buttonStyle(.bordered).disabled(store.busy || store.pending != nil || store.voice.active)
                                }
                            }
                            ForEach(store.messages) { message in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(message.role == "user" ? "You" : "Pip").font(.caption.bold()).foregroundStyle(.secondary)
                                    if message.role == "assistant" { ChatMarkdownView(text: message.text) }
                                    else { Text(message.text).textSelection(.enabled) }
                                    if let draft = message.trip_draft {
                                        if organizer.data.trips.contains(where: { $0.id == draft.id }) {
                                            Label("Trip saved", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                                        } else {
                                            Button("Review trip", systemImage: "suitcase") { reviewingTrip = draft }
                                                .buttonStyle(.borderedProminent)
                                                .disabled(!organizer.loaded || organizer.busy || organizer.pending != nil)
                                        }
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(message.role == "user" ? Color.accentColor.opacity(0.10) : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                                .id(message.id)
                            }
                            if let savedTripName { Text("Saved \(savedTripName) to your trips.").foregroundStyle(.green) }
                            if !store.messages.isEmpty {
                                Button("Create trip from this chat", systemImage: "suitcase") {
                                    store.composer = "Prepare a new trip draft from the latest agreed plan in this chat for me to review and save."
                                    Task { await store.send() }
                                }
                                .disabled(store.voice.active || !store.loaded || store.busy || store.pending != nil || !store.composer.isEmpty)
                            }
                            if store.busy { ProgressView("Pip is thinking…") }
                            if let error = store.error { Text(error).foregroundStyle(.red) }
                            if store.conflict != nil {
                                Text("This chat changed elsewhere. Load it to review before sending your draft again.")
                                Button("Load latest chat") { store.useLatest() }
                            } else if store.pending != nil && !store.busy {
                                Button("Retry same message") { Task { await store.retry() } }
                            } else if !store.loaded && !store.busy {
                                Button("Try again") { Task { await store.load() } }
                            }
                        }.padding()
                    }
                    .onChange(of: store.messages.last?.id) { _, id in
                        if let id { withAnimation { scroll.scrollTo(id, anchor: .bottom) } }
                    }
                }
                VStack(spacing: 8) {
                    Button("Talk to Pip", systemImage: "mic.fill") { showVoice = true }
                        .buttonStyle(.bordered)
                        .disabled(store.busy || store.pending != nil)
                    Text("Your chat and profile are shared with OpenAI. Saved trips and companions stay separate.")
                        .font(.caption2).foregroundStyle(.secondary)
                    HStack(alignment: .bottom) {
                        TextField("Ask about your trip…", text: $store.composer, axis: .vertical)
                            .lineLimit(1...5).textFieldStyle(.roundedBorder)
                            .disabled(store.busy || store.pending != nil || store.voice.active)
                        Button { Task { await store.send() } } label: {
                            Image(systemName: "arrow.up.circle.fill").font(.title)
                        }.accessibilityLabel("Send message")
                            .disabled(store.voice.active || !store.loaded || store.busy || store.pending != nil || store.composer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.composer.count > 4000)
                    }
                    if store.composer.count > 4000 { Text("Keep your message under 4,000 characters.").font(.caption).foregroundStyle(.red) }
                }.padding().background(.bar)
            }
            .navigationTitle("Ask Pip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if store.voice.active { Button("End voice", role: .destructive) { store.voice.stop() } }
                Button("Done") { dismiss() }
            }
            .task { if !store.loaded { await store.load() } }
            .sheet(isPresented: $showVoice) { VoiceConversationSheet(store: store.voice) }
            .sheet(item: $reviewingTrip) { draft in
                OrganizerEditor(store: organizer, kind: .trip(draft.id), initialTrip: draft) { _ in
                    savedTripName = organizer.data.trips.first { $0.id == draft.id }?.name
                }
            }
        }
    }
}

/// Native text rendering keeps AI replies selectable and avoids executing HTML.
struct ChatMarkdownBlock: Identifiable, Equatable {
    enum Kind: Equatable { case paragraph, heading(Int), bullet, numbered(String), quote, code }
    var id: Int
    var kind: Kind
    var text: String

    static func parse(_ source: String) -> [Self] {
        var blocks: [Self] = []
        var paragraph: [String] = []
        var code: [String]? = nil
        func append(_ kind: Kind, _ text: String) {
            blocks.append(Self(id: blocks.count, kind: kind, text: text))
        }
        func flush() {
            if !paragraph.isEmpty { append(.paragraph, paragraph.joined(separator: "\n")); paragraph = [] }
        }
        for line in source.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                flush()
                if let lines = code { append(.code, lines.joined(separator: "\n")); code = nil }
                else { code = [] }
                continue
            }
            if code != nil { code?.append(line); continue }
            if trimmed.isEmpty { flush(); continue }
            let hashes = trimmed.prefix { $0 == "#" }.count
            if (1...6).contains(hashes), trimmed.dropFirst(hashes).first == " " {
                flush(); append(.heading(hashes), String(trimmed.dropFirst(hashes + 1))); continue
            }
            if ["- ", "* ", "+ ", "• "].contains(where: { trimmed.hasPrefix($0) }) {
                flush(); append(.bullet, String(trimmed.dropFirst(2))); continue
            }
            let digits = trimmed.prefix { $0.isNumber }
            let remainder = trimmed.dropFirst(digits.count)
            if !digits.isEmpty, remainder.hasPrefix(". ") || remainder.hasPrefix(") ") {
                flush(); append(.numbered(String(digits) + "."), String(remainder.dropFirst(2))); continue
            }
            if trimmed.hasPrefix("> ") {
                flush(); append(.quote, String(trimmed.dropFirst(2))); continue
            }
            paragraph.append(line)
        }
        flush()
        if let code { append(.code, code.joined(separator: "\n")) }
        return blocks
    }

    var attributed: AttributedString {
        var result = (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
        // Only ordinary web links can be opened from AI-generated text.
        for run in result.runs {
            if let link = run.link, !["https", "http"].contains(link.scheme?.lowercased() ?? "") {
                result[run.range].link = nil
            }
        }
        return result
    }
}

struct ChatMarkdownView: View {
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(ChatMarkdownBlock.parse(text)) { block in
                switch block.kind {
                case .heading(let level):
                    Text(block.attributed).font(level == 1 ? .title3.bold() : .headline)
                case .bullet:
                    HStack(alignment: .top, spacing: 8) { Text("•"); Text(block.attributed) }
                case .numbered(let marker):
                    HStack(alignment: .top, spacing: 8) { Text(marker).monospacedDigit(); Text(block.attributed) }
                case .quote:
                    HStack(alignment: .top, spacing: 8) {
                        Rectangle().fill(.secondary).frame(width: 3)
                        Text(block.attributed).foregroundStyle(.secondary)
                    }.fixedSize(horizontal: false, vertical: true)
                case .code:
                    Text(block.text).font(.system(.body, design: .monospaced))
                case .paragraph:
                    Text(block.attributed)
                }
            }
        }.textSelection(.enabled)
    }
}

struct OrganizerCategoryCost: Codable, Equatable, Sendable {
    var estimated = ""
    var actual = ""
}
struct OrganizerBudget: Codable, Equatable, Sendable {
    var currency = "USD"
    var total = ""
    var flights = OrganizerCategoryCost()
    var hotels = OrganizerCategoryCost()
    var transport = OrganizerCategoryCost()
    var food = OrganizerCategoryCost()
    var activities = OrganizerCategoryCost()
    var other = OrganizerCategoryCost()
    var categories: [OrganizerCategoryCost] { [flights, hotels, transport, food, activities, other] }
    static func amount(_ text: String) -> Decimal? {
        guard !text.isEmpty else { return nil }
        return Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))
    }
    var estimatedTotal: Decimal { categories.reduce(0) { $0 + (Self.amount($1.estimated) ?? 0) } }
    var actualTotal: Decimal { categories.reduce(0) { $0 + (Self.amount($1.actual) ?? 0) } }
    var remaining: Decimal? { Self.amount(total).map { $0 - actualTotal } }
    var unallocated: Decimal? { Self.amount(total).map { $0 - estimatedTotal } }
    var isValid: Bool {
        let pattern = currency == "JPY" ? #"^[0-9]{1,9}(?:\.0{1,2})?$"# : #"^[0-9]{1,9}(?:\.[0-9]{1,2})?$"#
        return ([total] + categories.flatMap { [$0.estimated, $0.actual] }).allSatisfy {
            $0.isEmpty || $0.range(of: pattern, options: .regularExpression) != nil
        }
    }
    func formatted(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: currency))
    }
}

struct OrganizerBudgetView: View {
    @Binding var budget: OrganizerBudget
    var body: some View {
        Form {
            Section("Trip budget") {
                Picker("Currency", selection: $budget.currency) {
                    ForEach(["USD", "CAD", "EUR", "GBP", "AUD", "JPY"], id: \.self) { Text($0).tag($0) }
                }
                BudgetAmountField(title: "Total budget", value: $budget.total)
                Text("All costs use this currency. Changing it does not convert amounts.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Summary") {
                LabeledContent("Estimated total", value: budget.formatted(budget.estimatedTotal))
                LabeledContent("Actual spent", value: budget.formatted(budget.actualTotal))
                if let unallocated = budget.unallocated {
                    LabeledContent(unallocated < 0 ? "Estimates over budget" : "Not yet allocated", value: budget.formatted(abs(unallocated)))
                        .foregroundStyle(unallocated < 0 ? Color.red : Color.primary)
                }
                if let remaining = budget.remaining {
                    LabeledContent(remaining < 0 ? "Over budget" : "Remaining budget", value: budget.formatted(abs(remaining)))
                        .foregroundStyle(remaining < 0 ? Color.red : Color.primary)
                }
                Text("Totals include entered costs only. Leave unknown costs blank. Estimates and actual spending are counted separately.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            costSection("Flights", cost: $budget.flights)
            costSection("Hotels & stays", cost: $budget.hotels)
            costSection("Transport", cost: $budget.transport)
            costSection("Food", cost: $budget.food)
            costSection("Activities", cost: $budget.activities)
            costSection("Other", cost: $budget.other)
            if !budget.isValid {
                Text("Use numbers with up to two decimal places, or whole yen for JPY. Negative amounts are not supported.").foregroundStyle(.red)
            }
        }
        .navigationTitle("Budget & costs")
        .navigationBarTitleDisplayMode(.inline)
    }
    private func costSection(_ title: String, cost: Binding<OrganizerCategoryCost>) -> some View {
        Section(title) {
            BudgetAmountField(title: "Estimated", value: cost.estimated)
            BudgetAmountField(title: "Actual", value: cost.actual)
        }
    }
}
struct BudgetAmountField: View {
    let title: String
    @Binding var value: String
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("Not entered", text: Binding(get: { value }, set: { value = $0.replacingOccurrences(of: ",", with: ".") }))
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                .accessibilityLabel(title)
        }
    }
}
