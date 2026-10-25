import Foundation
import SwiftUI
import TenazCore

/// Today's writing as a sheet over the main window (Home's Write card, the popover, the review end
/// screen). Saving stores a `writing_entry` (graded later by Claude) and counts as the day's production.
struct WriteSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(TodayModel.self) private var today
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var text = ""
    @State private var result: WriteResult?
    /// The prompt as it was when the sheet opened: saving refreshes Today (a new prompt), and the
    /// done view must not change size or text under the learner.
    @State private var shown: TodayWritePrompt?

    private var prompt: TodayWritePrompt? { shown ?? today.summary.write }

    var body: some View {
        WriteBoard(prompt: prompt, text: $text, result: result, stage: today.summary.stage, save: save, close: close)
            .onAppear {
                shown = today.summary.write
                Self.markShown(shown, env: env)
            }
    }

    /// The prompt reached the screen: one `exposure` row per prompt per day (reopening the sheet on
    /// the same unanswered prompt is not a new exposure).
    static func markShown(_ prompt: TodayWritePrompt?, env: AppEnvironment, now: Date = Date()) {
        guard let prompt, let database = env.database else { return }
        let store = ExposureStore(database: database)
        if let last = try? store.all().last(where: { $0.surface == ExposureSurface.write.rawValue }), last.itemId == prompt.id,
           DayBoundary.day(for: Date(unixMilliseconds: last.ts)) == DayBoundary.day(for: now) { return }
        do {
            try store.record(ExposureRecord(itemId: prompt.id, groupId: prompt.group, surface: .write, kind: prompt.kind.rawValue, at: now))
        } catch {
            NSLog("Tenaz: write exposure not recorded: \(error)")
        }
    }

    private func close() {
        today.refresh()
        dismiss()
    }

    private func save() {
        let prompt = self.prompt
        let check = WriteCheck(text: text, prompt: prompt)
        guard check.canSubmit, result == nil else { return }
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        Self.store(body, prompt: prompt, env: env)
        var earned = WriteResult(xp: 0, dayQualified: false, words: check.words)
        if let engine = env.gamification {
            do {
                let effects = try engine.handle(.productionDone(Production(refId: prompt?.id ?? "write", quality: check.quality,
                                                                           words: check.words, text: body)))
                earned.xp = effects.xp
                earned.dayQualified = effects.dayQualified || (try? engine.state().today.qualified) == true
            } catch {
                NSLog("Tenaz: writing XP not recorded: \(error)")
            }
        }
        withAnimation(Motion.animation(.pop, reduceMotion: reduceMotion)) { result = earned }
        today.refresh()
    }

    /// A `writing_entry` with a queued Claude grade (the app's one queue grades it in the background;
    /// the weekly review and the error ledger pick the corrections up). Saving never waits on Claude.
    static func store(_ text: String, prompt: TodayWritePrompt?, env: AppEnvironment) {
        guard let database = env.database else { return }
        do {
            try ExamStore(database: database).saveWriting(surface: "write", promptId: prompt?.id,
                                                          prompt: prompt.map { $0.taskPrompt.isEmpty ? $0.prompt : $0.taskPrompt } ?? "",
                                                          text: text, at: Date())
            env.grading.nudge()
        } catch {
            NSLog("Tenaz: writing not saved: \(error)")
        }
    }
}
