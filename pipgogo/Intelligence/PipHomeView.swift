import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct PipHomeView: View {
    @Bindable var store: IntelligenceStore
    let signOut: () -> Void
    @AppStorage("pip.language") private var language = "en"
    @State private var showIntake = false
    @State private var showMemory = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .top) {
                        Text("🦆").font(.system(size: 48)).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("A little less planning.\nA little more exploring.").font(.largeTitle.bold())
                            Text("I'm Pip. Let's make this trip feel like you.").foregroundStyle(.secondary)
                        }
                    }.padding(.top, 16)
                    Button {
                        store.newTrip(language: language); showIntake = true
                    } label: {
                        Label("Where are we going?", systemImage: "plus").frame(maxWidth: .infinity).padding(10)
                    }.buttonStyle(.borderedProminent).disabled(store.hasPending || store.busy).accessibilityIdentifier("pip.createTrip")
                    PipErrorView(store: store)
                    if store.busy { ProgressView() }
                    if store.loaded && store.journeys.isEmpty {
                        ContentUnavailableView("Your next chapter starts here", systemImage: "suitcase.rolling", description: Text("Choose a destination and timing. We'll work out the rest together."))
                    }
                    ForEach(store.journeys) { trip in
                        NavigationLink {
                            PipTripView(store: store, tripID: UUID(uuidString: trip.id)!)
                        } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "map").foregroundStyle(.teal)
                                    Text(trip.data.intake.destination).font(.title2.bold())
                                    Spacer(); Image(systemName: "chevron.right").font(.caption)
                                }
                                Text(trip.data.intake.approximate_dates.isEmpty ? "\(trip.data.intake.duration_days ?? 1) days" : trip.data.intake.approximate_dates).foregroundStyle(.secondary)
                                Text(LocalizedStringKey(trip.data.intake.planning_state)).font(.caption.weight(.semibold))
                            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                                .background(.background, in: RoundedRectangle(cornerRadius: 22))
                        }.buttonStyle(.plain)
                    }
                }.padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("PipPipGo")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("What Pip remembers", systemImage: "sparkles") { showMemory = true }
                        Button("Language", systemImage: "globe") { showSettings = true }
                        Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive, action: signOut)
                    } label: { Image(systemName: "person.crop.circle").accessibilityLabel("Settings") }
                }
            }
            .sheet(isPresented: $showIntake) { TripIntakeView(store: store) }
            .sheet(isPresented: $showMemory) { MemoryView(store: store) }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    Form {
                        Picker("Application language", selection: $language) {
                            Text("English").tag("en"); Text("فارسی").tag("fa")
                        }
                        Text("Changing language keeps your trips and memories.")
                    }.navigationTitle("Language")
                }.presentationDetents([.medium])
            }
            .task { await store.refresh() }
            .refreshable { await store.refresh() }
        }
        .tint(.teal)
        .environment(\.locale, Locale(identifier: language))
        .environment(\.layoutDirection, language == "fa" ? .rightToLeft : .leftToRight)
    }
}

struct PipErrorView: View {
    @Bindable var store: IntelligenceStore
    var body: some View {
        if let error = store.error {
            VStack(alignment: .leading, spacing: 12) {
                Text(error).foregroundStyle(.red)
                if let conflict = store.conflict {
                    Text("This trip changed elsewhere. Your draft is still here.").font(.headline)
                    Text("Saved destination: \(conflict.data.intake.destination)")
                    Text("Saved notes: \(conflict.data.intake.notes)")
                    DisclosureGroup("Review saved trip") {
                        Text(String(data: (try? APIJSON.encoder().encode(conflict.data.intake)) ?? Data(), encoding: .utf8) ?? "").font(.caption).textSelection(.enabled)
                    }
                    Button("Keep my draft for a new save") { store.keepDraftAfterReview() }
                    Button("Use the saved trip", role: .destructive) { store.useServerAfterReview() }
                } else if store.hasPending {
                    Text("Your request is kept unchanged for a safe retry.").font(.caption)
                    Button("Retry same request") { Task { if store.pending != nil { await store.retry() } else { await store.retryAux() } } }.disabled(store.busy)
                } else {
                    Button("Reload") { Task { await store.refresh() } }.disabled(store.busy)
                }
            }.padding().background(Color.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct TripIntakeView: View {
    @Bindable var store: IntelligenceStore
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    private var locked: Bool { store.busy || store.hasPending }
    var body: some View {
        NavigationStack {
            Form {
                Section { Text("Only what matters for this trip. You can add more later.").foregroundStyle(.secondary) }
                if step == 0 {
                    Section("Where are we going?") {
                        TextField("Destination", text: $store.draft.destination).accessibilityIdentifier("intake.destination")
                        TextField("Approximate dates, e.g. October", text: $store.draft.approximate_dates)
                        Stepper("\(store.draft.duration_days ?? 4) days", value: Binding(get: { store.draft.duration_days ?? 4 }, set: { store.draft.duration_days = $0 }), in: 1...365)
                    }
                    Section("How much is already planned?") {
                        Picker("Existing plans", selection: $store.draft.planning_state) {
                            Text("Mostly planned").tag("mostly_planned")
                            Text("Partly planned").tag("partly_planned")
                            Text("Starting from scratch").tag("starting_from_scratch")
                        }.pickerStyle(.inline)
                        TextField("Anything already planned?", text: $store.draft.existing_plans, axis: .vertical)
                    }
                } else if step == 1 {
                    Section("Who's coming?") {
                        if store.draft.travelers.isEmpty { Text("Just me for now").foregroundStyle(.secondary) }
                        ForEach($store.draft.travelers) { $traveler in
                            VStack(alignment: .leading) {
                                TextField("Name or nickname (optional)", text: $traveler.name)
                                TextField("Relationship (optional)", text: $traveler.relationship)
                                TextField("Age or age range (optional)", text: $traveler.age_or_range)
                                TextField("Preferred language (optional)", text: $traveler.language)
                                TextField("Interests for this trip", text: $traveler.preferences, axis: .vertical)
                                Picker("Anything to take into account?", selection: $traveler.needs_response) {
                                    Text("Not now").tag("not_asked"); Text("None").tag("none")
                                    Text("Add details").tag("provided"); Text("Prefer not to answer").tag("prefer_not_to_answer")
                                }
                                if traveler.needs_response == "provided" { TextField("Practical needs", text: $traveler.needs, axis: .vertical) }
                                Button("Save as a recurring traveler") { Task { await store.saveTraveler(traveler) } }.disabled(store.hasPending || store.busy)
                                Button("Remove traveler", role: .destructive) { store.draft.travelers.removeAll { $0.id == traveler.id } }
                            }
                        }
                        Button("Add traveler", systemImage: "person.badge.plus") { store.draft.travelers.append(TripTraveler()) }
                        ForEach(store.travelers) { saved in
                            Button(saved.data.name.isEmpty ? String(localized: "Saved traveler") : saved.data.name) {
                                var person = saved.data; person.id = UUID(); person.saved_traveler_id = UUID(uuidString: saved.id)
                                store.draft.travelers.append(person)
                            }
                        }
                    }
                    Section("How are we getting around?") {
                        ForEach(["own_car", "rental_car", "public_transit", "train", "taxi", "walking", "bicycle", "cruise", "not_sure"], id: \.self) { mode in
                            Toggle(LocalizedStringKey(mode), isOn: Binding(get: { store.draft.transportation.contains(mode) }, set: { selected in
                                store.draft.transportation.removeAll { $0 == mode }; if selected { store.draft.transportation.append(mode) }
                            }))
                        }
                        TextField("Transportation details", text: $store.draft.transportation_notes, axis: .vertical)
                    }
                } else {
                    Section("Where are we staying?") {
                        TextField("Property (leave blank if not booked)", text: $store.draft.lodging.property_name)
                        TextField("Address", text: $store.draft.lodging.address)
                        TextField("Check-in date and time", text: $store.draft.lodging.check_in)
                        TextField("Check-out date and time", text: $store.draft.lodging.check_out)
                        TextField("Confirmation reference", text: $store.draft.lodging.reference)
                        TextField("Arrival instructions", text: $store.draft.lodging.instructions, axis: .vertical)
                    }
                    Section("Anything booked that I should protect?") {
                        ForEach($store.draft.commitments) { $item in
                            VStack {
                                TextField("Booking or commitment", text: $item.title)
                                TextField("Date and time", text: $item.timing)
                                TextField("Location", text: $item.location)
                                Button("Remove commitment", role: .destructive) { store.draft.commitments.removeAll { $0.id == item.id } }
                            }
                        }
                        Button("Add fixed commitment") { store.draft.commitments.append(FixedCommitment()) }
                    }
                    Section("Anything else?") {
                        TextField("Optional needs, budget, must-dos or things to avoid", text: $store.draft.constraints, axis: .vertical)
                        TextField("Notes", text: $store.draft.notes, axis: .vertical)
                        Text("These details apply to this trip. They do not become permanent preferences.").font(.caption)
                    }
                }
                Section {
                    if step < 2 {
                        Button("Continue") { step += 1 }.disabled(store.draft.destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Button(step < 2 ? "Save trip; add details later" : "Save trip") {
                        Task { await store.saveIntake(); if store.pending == nil && store.error == nil { dismiss() } }
                    }.disabled(store.draft.destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .disabled(locked)
                PipErrorView(store: store)
            }
            .disabled(locked)
            .safeAreaInset(edge: .bottom) { if store.error != nil { PipErrorView(store: store).padding() } }
            .navigationTitle(step == 0 ? "Your trip" : step == 1 ? "Traveling together" : "Make room for what matters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                if step > 0 { ToolbarItem(placement: .topBarLeading) { Button("Back") { step -= 1 } } }
            }
        }.interactiveDismissDisabled(store.busy)
    }
}

struct PipTripView: View {
    @Bindable var store: IntelligenceStore
    let tripID: UUID
    @State private var showIntake = false
    @State private var showImport = false
    @State private var review: TripImport?
    @State private var tab = "conversation"
    @State private var memorySuggestion: String?
    @State private var showMemory = false
    var body: some View {
        Group {
            if let trip = store.journeys.first(where: { $0.id == tripID.uuidString.lowercased() }) {
                VStack(spacing: 0) {
                    Picker("View", selection: $tab) {
                        Text("Talk to Pip").tag("conversation"); Text("Our plan").tag("plan"); Text("Trip details").tag("details")
                    }.pickerStyle(.segmented).padding()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            if tab == "conversation" {
                                if trip.data.messages.isEmpty {
                                    Text("🦆 Hi, I'm Pip.").font(.title2.bold())
                                    Text("I'll travel with you, help when you need me, and get to know what you like along the way.")
                                    if store.memories.isEmpty && !trip.data.onboarding_done {
                                        Text("Tell me about a trip, vacation, or even a day out that you really enjoyed. What made it good?").font(.headline)
                                    } else { Text("What would make this trip feel right for you?").font(.headline) }
                                }
                                ForEach(trip.data.messages) { message in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(message.role == "pip" ? "Pip 🦆" : "You").font(.caption.bold()).foregroundStyle(.secondary)
                                        Text(message.text).textSelection(.enabled)
                                        ForEach(message.memory_observations ?? [], id: \.self) { observation in
                                            Button(observation) { memorySuggestion = observation; showMemory = true }.font(.caption)
                                        }
                                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                        .background(message.role == "pip" ? Color.teal.opacity(0.08) : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                                }
                                if trip.data.onboarding_done || !store.memories.isEmpty {
                                    Button("Create a lightweight plan", systemImage: "sparkles") { Task { await store.act(PipAction(action: "plan")); tab = "plan" } }
                                } else {
                                    Button("Skip; continue with my trip") { Task { await store.act(PipAction(action: "skip_onboarding")) } }
                                }
                            } else if tab == "plan" {
                                Text("Room to explore").font(.title.bold())
                                Text("Suggestions are not bookings. Live hours, weather and availability have not been verified.").font(.caption).foregroundStyle(.secondary)
                                ForEach(trip.data.intake.commitments) { item in
                                    Label(item.title, systemImage: "lock.fill").font(.headline)
                                    Text(item.timing + " · " + item.location).foregroundStyle(.secondary)
                                }
                                ForEach(trip.data.imports.filter { $0.status == "confirmed" }) { item in
                                    ForEach(Array(item.confirmed_facts.enumerated()), id: \.offset) { _, fact in
                                        Label(fact.title, systemImage: "checkmark.seal")
                                        Text(fact.details).font(.caption)
                                    }
                                }
                                ForEach(trip.data.plan) { item in PlanItemView(item: item) }
                                if let proposal = trip.data.proposal {
                                    Divider(); Text("A suggestion for you").font(.title2.bold()); Text(proposal.explanation)
                                    ForEach(proposal.items) { item in PlanItemView(item: item) }
                                    HStack {
                                        Button("Accept changes") { Task { await store.act(PipAction(action: "accept_plan", proposal_id: proposal.id)) } }.buttonStyle(.borderedProminent)
                                        Button("Keep current plan") { Task { await store.act(PipAction(action: "reject_plan", proposal_id: proposal.id)) } }.buttonStyle(.bordered)
                                    }
                                } else if trip.data.plan.isEmpty {
                                    Button("Create a lightweight plan") { Task { await store.act(PipAction(action: "plan")) } }.buttonStyle(.borderedProminent)
                                }
                            } else {
                                Text(trip.data.intake.destination).font(.title.bold())
                                Text(trip.data.intake.constraints)
                                Text(trip.data.intake.lodging.property_name)
                                Text(trip.data.intake.lodging.address)
                                Text(trip.data.intake.existing_plans)
                                Button("Edit trip details") { store.edit(trip); showIntake = true }
                                Button("Import existing plans", systemImage: "paperclip") { showImport = true }
                                ForEach(trip.data.imports) { item in
                                    VStack(alignment: .leading) {
                                        Text(item.filename).font(.headline)
                                        Text(LocalizedStringKey(item.status))
                                        if item.status == "proposed" { Button("Review extracted details") { review = item } }
                                    }.padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                                }
                            }
                            PipErrorView(store: store)
                            if store.busy { ProgressView("Pip is thinking…") }
                        }.padding(20)

                    }
                    if tab != "details" {
                        HStack(alignment: .bottom) {
                            Button { showImport = true } label: { Image(systemName: "plus.circle.fill").font(.title2).accessibilityLabel("Attach existing plans") }
                            TextField("Tell Pip…", text: $store.composer, axis: .vertical).lineLimit(1...5).padding(10).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                            Button {
                                Task { await store.act(PipAction(action: tab == "plan" ? "feedback" : "conversation", text: store.composer)) }
                            } label: { Image(systemName: "arrow.up.circle.fill").font(.title).accessibilityLabel("Send") }
                            .disabled(store.composer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }.padding().disabled(store.busy || store.hasPending)
                    }
                }
                .navigationTitle(trip.data.intake.destination).navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showMemory) { MemoryView(store: store, initialValue: memorySuggestion ?? "") }
                .sheet(isPresented: $showIntake) { TripIntakeView(store: store) }
                .sheet(isPresented: $showImport) { ImportView(store: store) }
                .sheet(item: $review) { item in ImportReviewView(store: store, item: item) }
            } else { ContentUnavailableView("Trip unavailable", systemImage: "suitcase") }
        }.onAppear { store.selectedID = tripID }
    }
}
struct PlanItemView: View {
    let item: PipPlanItem
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(item.timing).font(.caption).foregroundStyle(.teal)
            Text(item.title).font(.headline); Text(item.location).font(.subheadline)
            Text(item.rationale).font(.caption).foregroundStyle(.secondary)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}
struct ImportView: View {
    @Bindable var store: IntelligenceStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var file: PipImportRequest?
    @State private var photo: PhotosPickerItem?
    @State private var pickFile = false
    @State private var message: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Send a booking, itinerary, or screenshot. Pip proposes details for you to review before anything is used in your plan.")
                    Text("The selected content is sent to Pip's server and OpenAI for extraction. Raw files are not saved by Pip. Extracted details stay with this trip.").font(.caption)
                }
                Section("Already booked anything?") {
                    TextField("Paste booking details", text: $text, axis: .vertical).lineLimit(4...10)
                    PhotosPicker(selection: $photo, matching: .images) { Label("Choose photo", systemImage: "photo") }
                    Button("Choose PDF or DOCX", systemImage: "doc") { pickFile = true }
                    if let file { Text(file.filename) }
                    if let message { Text(message).foregroundStyle(.red) }
                }
                Button("Extract for review") {
                    Task {
                        var request = file ?? PipImportRequest(filename: "Pasted details"); request.text = text
                        await store.importDetails(request)
                        if store.error == nil { dismiss() }
                    }
                }.disabled(store.busy || store.hasPending || (file == nil && text.isEmpty))
                PipErrorView(store: store)
            }.navigationTitle("Send it to Pip")
                .toolbar { Button("Close") { dismiss() } }
                .fileImporter(isPresented: $pickFile, allowedContentTypes: [.pdf, UTType(filenameExtension: "docx")!]) { result in
                    do {
                        let url = try result.get(); let access = url.startAccessingSecurityScopedResource()
                        defer { if access { url.stopAccessingSecurityScopedResource() } }
                        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                        guard size <= 5_000_000 else { message = String(localized: "Please use a file smaller than 5 MB."); return }
                        let data = try Data(contentsOf: url)
                        file = PipImportRequest(filename: url.lastPathComponent, content_base64: data.base64EncodedString())
                    } catch { message = error.localizedDescription }
                }
                .onChange(of: photo) { _, selection in
                    Task {
                        do {
                            if let data = try await selection?.loadTransferable(type: Data.self), let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.7) {
                                guard jpeg.count <= 5_000_000 else { message = String(localized: "Please use a file smaller than 5 MB."); return }
                                file = PipImportRequest(filename: "Photo.jpg", content_base64: jpeg.base64EncodedString())
                            }
                        } catch { message = error.localizedDescription }
                    }
                }
        }
    }
}
struct ImportReviewView: View {
    @Bindable var store: IntelligenceStore
    let item: TripImport
    @Environment(\.dismiss) private var dismiss
    @State private var facts: [ImportFact] = []
    var body: some View {
        NavigationStack {
            Form {
                Text(item.explanation)
                ForEach(facts.indices, id: \.self) { index in
                    Section {
                        TextField("Title", text: $facts[index].title)
                        TextField("Details", text: $facts[index].details, axis: .vertical)
                        TextField("Date and time", text: $facts[index].timing)
                        TextField("Location", text: $facts[index].location)
                        Button("Remove this detail", role: .destructive) { facts.remove(at: index) }
                    }
                }
                Button("Confirm these details") { Task { await review(facts) } }.disabled(facts.isEmpty)
                Button("Reject import", role: .destructive) { Task { await review([]) } }
                PipErrorView(store: store)
            }.navigationTitle("Review before adding")
                .onAppear { facts = item.facts }
        }
    }
    func review(_ selected: [ImportFact]) async {
        await store.act(PipAction(action: "review_import", import_id: item.id, facts: selected))
        if store.error == nil { dismiss() }
    }
}
struct MemoryView: View {
    @Bindable var store: IntelligenceStore
    var initialValue = ""
    @State private var editing: APIRecord<TravelerMemory>?
    @State private var value = ""
    @State private var tripOnly = false
    @State private var forgetting: APIRecord<TravelerMemory>?
    var body: some View {
        NavigationStack {
            Form {
                Section { Text("You can correct Pip anytime. Temporary trip needs stay separate from what you want remembered.") }
                ForEach(store.memories) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.data.value)
                        Text(LocalizedStringKey(item.data.scope)).font(.caption).foregroundStyle(.secondary)
                        Button("Correct this") { editing = item; value = item.data.value; tripOnly = item.data.scope == "trip_specific" }
                        Button("Don't remember that", role: .destructive) { forgetting = item }
                    }
                }
                Section("Something you'd like Pip to remember?") {
                    TextField("In your own words", text: $value, axis: .vertical)
                    if store.selectedID != nil { Toggle("Only for this trip", isOn: $tripOnly) }
                    Button("Remember this") {
                        Task {
                            var memory = TravelerMemory(); memory.key = UUID().uuidString; memory.value = value; memory.original_text = value
                            if tripOnly { memory.scope = "trip_specific"; memory.trip_id = store.selectedID }
                            if !initialValue.isEmpty { memory.status = "confirmed"; memory.source_type = "conversation_review" }
                            if let editing { memory.key = editing.data.key; memory.status = "confirmed" }
                            await store.saveMemory(memory, id: editing.flatMap { UUID(uuidString: $0.id) } ?? UUID(), version: editing?.version ?? 0)
                            if store.error == nil { value = ""; editing = nil }
                        }
                    }.disabled(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.busy)
                }
                PipErrorView(store: store)
            }.navigationTitle("What Pip remembers")
                .onAppear { if !initialValue.isEmpty { value = initialValue } }
                .confirmationDialog("Forget this memory?", isPresented: Binding(get: { forgetting != nil }, set: { if !$0 { forgetting = nil } })) {
                    Button("Forget", role: .destructive) { if let forgetting { Task { await store.forget(forgetting); self.forgetting = nil } } }
                }
        }
    }
}
