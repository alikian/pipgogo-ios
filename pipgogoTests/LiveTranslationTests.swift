import Foundation
import Testing
@testable import pipgogo

struct LiveTranslationTests {
    @Test func pairsRequireDistinctSupportedLanguages() {
        #expect(TranslationPair(mine: "en", theirs: "es")?.headerValue == "en,es")
        #expect(TranslationPair(mine: "en", theirs: "en") == nil)
        #expect(TranslationPair(mine: "en", theirs: "xx") == nil)
        #expect(TranslationPair(headerValue: "fa,ja")?.theirs.name == "Japanese")
        #expect(TranslationPair(headerValue: "en,es,fr") == nil)
        #expect(TranslationPair(headerValue: "") == nil)
        #expect(TranslationPair(headerValue: "en,,es") == nil)
        #expect(TranslationPair(headerValue: ",en,es") == nil)
        #expect(TranslationPair(headerValue: "en,es,") == nil)
        #expect(TranslationPair(mine: "en", theirs: "es")?.swapped.headerValue == "es,en")
    }

    @Test func languageCodesAreUniqueTwoLetterCodes() {
        let codes = TranslationLanguage.all.map(\.code)
        #expect(Set(codes).count == codes.count)
        #expect(codes.allSatisfy { $0.count == 2 && $0 == $0.lowercased() })
    }

    @Test func defaultPairFollowsDeviceLanguage() {
        #expect(TranslationPair.defaultPair(locale: Locale(identifier: "fr_FR")).headerValue == "fr,es")
        #expect(TranslationPair.defaultPair(locale: Locale(identifier: "es_MX")).headerValue == "es,en")
        #expect(TranslationPair.defaultPair(locale: Locale(identifier: "sw_KE")).headerValue == "en,es")
    }

    @Test func savedPairRoundTripsAndIgnoresInvalidValues() throws {
        let defaults = try #require(UserDefaults(suiteName: "LiveTranslationTests-\(UUID())"))
        TranslationPair(mine: "ja", theirs: "ko")!.save(defaults)
        #expect(TranslationPair.saved(defaults).headerValue == "ja,ko")
        defaults.set("en,en", forKey: "translationLanguages")
        #expect(TranslationPair.saved(defaults) == TranslationPair.defaultPair())
    }

    @MainActor @Test func translationRequestUsesInterpreterEndpointWithoutNavigation() throws {
        let pair = try #require(TranslationPair(mine: "en", theirs: "it"))
        let request = try LiveVoiceStore.request(baseURL: URL(string: "https://dev.pippipgo.com")!, token: "test-access-token", mode: .translate(pair))
        #expect(request.url?.absoluteString == "wss://dev.pippipgo.com/v1/translate/live")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-access-token")
        #expect(request.value(forHTTPHeaderField: "X-Pip-Translate") == "en,it")
        #expect(request.value(forHTTPHeaderField: "X-Pip-Navigation") == nil)
        #expect(request.value(forHTTPHeaderField: "X-Pip-Context") == nil)
        let voice = try LiveVoiceStore.request(baseURL: URL(string: "https://dev.pippipgo.com")!, token: "t")
        #expect(voice.value(forHTTPHeaderField: "X-Pip-Translate") == nil)
        #expect(voice.value(forHTTPHeaderField: "X-Pip-Navigation") == "1")
    }

    @MainActor @Test func languagesChangeOnlyWhileInactive() throws {
        let store = LiveVoiceStore(client: APIClient(baseURL: URL(string: "https://example.invalid")!), authentication: NoTokens(),
                                   mode: .translate(TranslationPair(mine: "en", theirs: "es")!))
        let next = try #require(TranslationPair(mine: "en", theirs: "de"))
        store.setMode(.translate(next))
        #expect(store.mode.translation == next)
    }
}

private struct NoTokens: AccessTokenProviding {
    func validAccessToken(forceRefresh: Bool) async throws -> String { throw APIClientError.connection }
}
