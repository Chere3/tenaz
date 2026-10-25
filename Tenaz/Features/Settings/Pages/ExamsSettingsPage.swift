import SwiftUI

/// Exams: what Exam Mode does and how it is witnessed.
struct ExamsSettingsPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xl) {
            SettingsPageHeader(title: "Exams", subtitle: "TOEFL-style tests with an approximate IELTS band. During an exam only Tenaz may be in front.")
            SettingsCard(title: "Exam Mode", systemImage: "checklist") {
                SettingsRow(title: "Tivra witness", detail: "Tenaz reads Tivra's activity log after each exam (read-only) to check no AI app was used.") {
                    Chip("On · read-only", systemImage: "eye", state: .done)
                }
                SettingsRow(title: "Paste and system AI", detail: "Blocked in every answer field: paste, Writing Tools, predictions, autocorrect.") {
                    Chip("Blocked", systemImage: "nosign", state: .done)
                }
                SettingsRow(title: "A meeting starts", detail: "The exam pauses. Nothing is flagged.") {
                    Chip("Pauses", systemImage: "pause.fill", state: .idle)
                }
            }
            Text("Tenaz can catch common AI shortcuts. It can't prove you didn't use another device.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Tokens.brand)
        }
    }
}
