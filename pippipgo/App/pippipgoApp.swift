import SwiftUI

@main
struct pippipgoApp: App {
    @AppStorage("pip.language") private var language = "en"
    @State private var authenticationStore = AuthenticationStore()

    var body: some Scene {
        WindowGroup {
            RootView(store: authenticationStore)
                .environment(\.locale, Locale(identifier: AppLanguage.selected(language).rawValue))
                .environment(\.layoutDirection, AppLanguage.selected(language).direction)
                .task { await authenticationStore.restoreSession() }
        }
    }
}

/// Uses the existing language preference without recreating account or editor state.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case persian = "fa"
    case japanese = "ja"
    case spanish = "es"
    case french = "fr"
    case italian = "it"
    case simplifiedChinese = "zh-Hans"
    var id: String { rawValue }
    var nativeName: String {
        switch self {
        case .english: "English"
        case .persian: "فارسی"
        case .japanese: "日本語"
        case .spanish: "Español"
        case .french: "Français"
        case .italian: "Italiano"
        case .simplifiedChinese: "简体中文"
        }
    }
    var direction: LayoutDirection { self == .persian ? .rightToLeft : .leftToRight }
    static func selected(_ stored: String) -> AppLanguage { AppLanguage(rawValue: stored) ?? .english }
}

struct AppLanguageMenu: View {
    @AppStorage("pip.language") private var language = "en"
    var body: some View {
        Menu {
            Picker("Application language", selection: $language) {
                ForEach(AppLanguage.allCases) { choice in
                    Text(verbatim: choice.nativeName).tag(choice.rawValue)
                }
            }
        } label: {
            Label("Language", systemImage: "globe")
        }
        .accessibilityIdentifier("app.languagePicker")
        .accessibilityValue(AppLanguage.selected(language).nativeName)
    }
}

struct AppVersionView: View {
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    private let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"

    var body: some View {
        Text("Version \(version) (Build \(build))")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("app.versionAndBuild")
    }
}
