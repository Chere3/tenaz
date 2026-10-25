/// The Settings pages (PLAN F13). Safety is last and always reachable.
enum SettingsSection: String, CaseIterable, Identifiable {
    case intrusions, gate, exams, claude, sound, data, credits, safety

    var id: String { rawValue }

    var title: String {
        switch self {
        case .intrusions: "Intrusions"
        case .gate: "Unlock gate"
        case .exams: "Exams"
        case .claude: "Claude"
        case .sound: "Sound"
        case .data: "Data"
        case .credits: "Credits & licences"
        case .safety: "Safety"
        }
    }

    var symbol: String {
        switch self {
        case .intrusions: "rectangle.on.rectangle.angled"
        case .gate: "lock.open.display"
        case .exams: "checklist"
        case .claude: "sparkle"
        case .sound: "speaker.wave.2.fill"
        case .data: "externaldrive"
        case .credits: "text.book.closed"
        case .safety: "lifepreserver"
        }
    }
}
