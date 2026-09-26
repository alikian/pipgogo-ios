import SwiftUI

/// Select one language while retaining the backend string-array format.
struct LanguageSelectionView: View {
    @Binding var languages: [String]

    private static let choices = [
        "Afrikaans", "Albanian", "Amharic", "Arabic", "Armenian", "Assamese", "Azerbaijani",
        "Basque", "Belarusian", "Bengali", "Bosnian", "Bulgarian", "Burmese", "Cantonese",
        "Catalan", "Croatian", "Czech", "Danish", "Dutch", "English", "Estonian", "Filipino",
        "Finnish", "French", "Georgian", "German", "Greek", "Gujarati", "Haitian Creole",
        "Hausa", "Hebrew", "Hindi", "Hungarian", "Icelandic", "Igbo", "Indonesian", "Irish",
        "Italian", "Japanese", "Javanese", "Kannada", "Kazakh", "Khmer", "Korean", "Kurdish",
        "Kyrgyz", "Lao", "Latvian", "Lithuanian", "Macedonian", "Malay", "Malayalam", "Maltese",
        "Mandarin Chinese", "Marathi", "Mongolian", "Nepali", "Norwegian", "Odia", "Pashto",
        "Persian (Farsi)", "Polish", "Portuguese", "Punjabi", "Romanian", "Russian", "Serbian",
        "Sinhala", "Slovak", "Slovenian", "Somali", "Spanish", "Swahili", "Swedish", "Tajik",
        "Tamil", "Telugu", "Thai", "Tibetan", "Turkish", "Turkmen", "Ukrainian", "Urdu",
        "Uzbek", "Vietnamese", "Welsh", "Yoruba", "Zulu"
    ]

    private var selection: Binding<String> {
        Binding(
            get: { languages.first ?? "" },
            set: { languages = $0.isEmpty ? [] : [$0] }
        )
    }

    private var availableChoices: [String] {
        Array(Set(Self.choices + languages.filter { !$0.isEmpty })).sorted()
    }

    var body: some View {
        Picker("Language", selection: selection) {
            Text("Not set").tag("")
            ForEach(availableChoices, id: \.self) { language in
                Text(language).tag(language)
            }
        }
        .pickerStyle(.menu)
    }
}
