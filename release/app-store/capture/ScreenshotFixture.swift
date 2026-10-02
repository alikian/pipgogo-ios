import SwiftUI
import Foundation

// Capture-only entry point, appended to a temporary copy of the app source.
// Never included in the shipping target. Uses the actual production views.
private struct ScreenshotTokens: AccessTokenProviding {
    func validAccessToken(forceRefresh: Bool) async throws -> String { "fictional-screenshot-token" }
}
private final class ScreenshotProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let messages = [
            TravelChatMessage(id: "demo-user", role: "user", text: "I'd love three relaxed days in Rome, with art, great food, and time to wander."),
            TravelChatMessage(id: "demo-pip", role: "assistant", text: "Let's give Rome room to breathe.\n\n**Day 1 · Settle in**\nExplore your neighborhood, then enjoy a leisurely dinner.\n\n**Day 2 · Art & a slow afternoon**\nSpend the morning at a gallery, leave time for lunch, and wander the city's little streets.\n\n**Day 3 · Your kind of Rome**\nChoose a café, revisit a favorite spot, and leave the afternoon open.\n\nWould you like ideas for vegetarian restaurants?")
        ]
        let record = APIRecord(id: "demo-chat", kind: "travel_chat", version: 1, revision: 1, updatedAt: Date(), deleted: false, data: TravelChatData(messages: messages))
        let data = try! APIJSON.encoder().encode(record)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor private struct ScreenshotGallery: View {
    @State private var organizer: OrganizerStore
    @State private var chat: TravelChatStore
    @State private var selected: AppTab
    @State private var mode: PipMode
    @State private var editor: OrganizerEditorKind?
    @State private var reviewingTrip: OrganizerTrip?
    @State private var startRequest: UUID?
    @State private var budget: OrganizerBudget
    private let screen: String
    private let tripID: UUID

    init() {
        let screen = ProcessInfo.processInfo.arguments.last ?? "trips"
        self.screen = screen
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ScreenshotProtocol.self]
        let client = APIClient(baseURL: URL(string: "https://screenshots.invalid")!, urlSession: URLSession(configuration: configuration))
        let tokens = ScreenshotTokens()
        let organizer = OrganizerStore(client: client, authentication: tokens)
        let companion = OrganizerPerson(name: "Jamie", hometown: "Seattle", interests: "Art, food, and scenic walks")
        let budget = OrganizerBudget(currency: "EUR", total: "2500", flights: .init(estimated: "600", actual: "580"), hotels: .init(estimated: "900", actual: "450"), transport: .init(estimated: "150", actual: "65"), food: .init(estimated: "350", actual: "120"), activities: .init(estimated: "200", actual: "40"))
        let trip = OrganizerTrip(party: .init(adults: 2, children: 0), budget: budget, name: "Italy escape", companion_ids: [companion.id], stops: [
            OrganizerStop(destination: "Rome", arrival: "2026-11-06", departure: "2026-11-09", hotel: "A cozy stay in Trastevere", check_in: "2026-11-06", check_out: "2026-11-09", transport: "plane", transport_details: "Arrive Friday afternoon"),
            OrganizerStop(destination: "Florence", arrival: "2026-11-09", departure: "2026-11-12", hotel: "A little hotel near the Duomo", check_in: "2026-11-09", check_out: "2026-11-12", transport: "train", transport_details: "Rome → Florence · Monday morning")
        ], notes: "Art, good food, and unhurried afternoons.")
        organizer.data = OrganizerData(profile: OrganizerPerson(name: "Alex", hometown: "Seattle", interests: "Art, vegetarian food, and relaxed travel"), companions: [companion], trips: [trip,
            OrganizerTrip(name: "A weekend in Kyoto", stops: [OrganizerStop(destination: "Kyoto", arrival: "2027-03-19", departure: "2027-03-22")]),
            OrganizerTrip(name: "Pacific coast road trip", stops: [OrganizerStop(destination: "San Francisco"), OrganizerStop(destination: "Monterey"), OrganizerStop(destination: "Big Sur")])])
        organizer.loaded = true
        let chat = TravelChatStore(client: client, authentication: tokens, captureContext: { .snapshot(status: "unavailable") })
        chat.loaded = true
        chat.voice.transcript.append("I'd love a relaxed weekend in Paris with good food and a little art.", speaker: .user, startMilliseconds: 0, endMilliseconds: 4000)
        chat.voice.transcript.append("Let's start with a morning in Montmartre, lunch at a neighborhood bistro, and a walk along the Seine. Would you like to leave time for a museum?", speaker: .pip, startMilliseconds: 5000, endMilliseconds: 10000)
        chat.voice.transcript.append("Yes, and keep the afternoons flexible.", speaker: .user, startMilliseconds: 11000, endMilliseconds: 14000)
        chat.voice.transcript.append("Absolutely. One main activity each morning, with afternoons free to explore at your own pace.", speaker: .pip, startMilliseconds: 15000, endMilliseconds: 20000)
        chat.translator.setMode(.translate(TranslationPair(mine: "en", theirs: "ja")!))
        chat.translator.transcript.append("Excuse me, where is the nearest metro station?", speaker: .user, startMilliseconds: 0, endMilliseconds: 4000)
        chat.translator.transcript.append("すみません、最寄りの地下鉄の駅はどこですか？", speaker: .pip, startMilliseconds: 5000, endMilliseconds: 9000)
        chat.translator.transcript.append("この道をまっすぐ進んで、左に曲がってください。", speaker: .user, startMilliseconds: 10000, endMilliseconds: 14000)
        chat.translator.transcript.append("Go straight along this road, then turn left.", speaker: .pip, startMilliseconds: 15000, endMilliseconds: 19000)
        _organizer = State(initialValue: organizer)
        _chat = State(initialValue: chat)
        _budget = State(initialValue: budget)
        _selected = State(initialValue: ["chat": AppTab.pip, "voice": .pip, "translate": .translate, "profile": .profile][screen] ?? .trips)
        _mode = State(initialValue: screen == "voice" ? .voice : .chat)
        tripID = trip.id
    }

    var body: some View {
        TabView(selection: $selected) {
            Group {
                if screen == "details" {
                    NavigationStack {
                        TripDetailView(store: organizer, tripID: tripID, editor: $editor)
                    }
                } else if screen == "budget" {
                    NavigationStack { OrganizerBudgetView(budget: $budget) }
                } else {
                    TripsTab(store: organizer, editor: $editor, askPip: { selected = .pip })
                }
            }
            .tabItem { Label("Trips", systemImage: "suitcase") }.tag(AppTab.trips)
            PipTab(chat: chat, organizer: organizer, mode: $mode, reviewingTrip: $reviewingTrip, voiceStartRequest: $startRequest)
                .tabItem { Label("Pip", systemImage: "bubble.left.and.bubble.right") }.tag(AppTab.pip)
            TranslateTab(store: chat.translator)
                .tabItem { Label("Translate", systemImage: "translate") }.tag(AppTab.translate)
            ProfileTab(store: organizer, location: chat.locationDisplay, editor: $editor, signOut: {})
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }.tag(AppTab.profile)
        }
        .environment(\.locale, Locale(identifier: "en_US"))
        .environment(\.layoutDirection, .leftToRight)
        .preferredColorScheme(.light)
    }
}
