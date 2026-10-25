import SwiftUI

/// Credits & licences for what is actually bundled today (PLAN 4.8). Datasets that are planned but
/// not bundled are listed as such.
struct CreditsSettingsPage: View {
    private let bundled: [(String, String, String)] = [
        ("Tenaz content", "Original word lists, exam items and prompts written for Tenaz.", "Tenaz-original"),
        ("Fraunces", "Display typeface © 2018 The Fraunces Project Authors (Undercase Type).", "SIL Open Font License 1.1"),
        ("GRDB.swift", "SQLite toolkit by Gwendal Roué.", "MIT"),
        ("FSRS-6", "Spaced-repetition algorithm by open-spaced-repetition; Tenaz uses its own Swift port.", "MIT"),
        ("SF Pro Rounded", "Apple system font.", "Apple"),
    ]
    private let planned: [(String, String)] = [
        ("CEFR-J Wordlist 1.6", "free with citation"),
        ("NGSL 1.2 / NAWL", "CC BY-SA 4.0"),
        ("Tatoeba (English–Spanish)", "CC BY 2.0 FR, with each author"),
        ("CMU Pronouncing Dictionary", "free, credit requested"),
        ("WikDict en–es", "CC BY-SA 4.0"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xl) {
            SettingsPageHeader(title: "Credits & licences", subtitle: "Thank you to the people who made these.")
            SettingsCard(title: "In this app", systemImage: "shippingbox") {
                ForEach(bundled, id: \.0) { item in
                    SettingsRow(title: item.0, detail: item.1) { Chip(item.2, state: .idle) }
                }
            }
            SettingsCard(title: "Planned, not bundled yet", systemImage: "clock", note: "These open datasets will be credited here when they are added.") {
                ForEach(planned, id: \.0) { item in
                    SettingsRow(title: item.0) { Chip(item.1, state: .locked) }
                }
            }
        }
    }
}
