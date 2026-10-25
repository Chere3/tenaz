import SwiftUI

/// One line per screen. Keep entries sorted by name; each feature adds its own.
enum SnapshotRegistry {
    static func screens(_ env: AppEnvironment) -> [String: SnapshotEntry] {
        var all: [String: SnapshotEntry] = [
            "daily-check-question": SnapshotEntry(view: ExamSnapshots.dailyQuestion(env), size: ExamSnapshots.windowSize),
            "exam-build-sentence": SnapshotEntry(view: ExamSnapshots.buildSentence(env), size: ExamSnapshots.examSize),
            "exam-complete-words": SnapshotEntry(view: ExamSnapshots.completeWords(env), size: ExamSnapshots.examSize),
            "exam-listening": SnapshotEntry(view: ExamSnapshots.listening(env), size: ExamSnapshots.examSize),
            "exam-reading": SnapshotEntry(view: ExamSnapshots.reading(env), size: ExamSnapshots.examSize),
            "exam-results": SnapshotEntry(view: ExamSnapshots.results(env), size: CGSize(width: 1180, height: 1100)),
            "exam-section-intro": SnapshotEntry(view: ExamSnapshots.sectionIntro(env), size: ExamSnapshots.examSize),
            "exam-speaking-typed": SnapshotEntry(view: ExamSnapshots.speakingTyped(env), size: ExamSnapshots.examSize),
            "exam-writing": SnapshotEntry(view: ExamSnapshots.writing(env), size: ExamSnapshots.examSize),
            "exams-history": SnapshotEntry(view: ExamSnapshots.history(env), size: CGSize(width: 1180, height: 980)),
            "contract": IntrusionSnapshots.entry("contract", env),
            "gate-empty": IntrusionSnapshots.entry("gate-empty", env),
            "gate-ready": IntrusionSnapshots.entry("gate-ready", env),
            "gate-later": IntrusionSnapshots.entry("gate-later", env),
            "gate-story": IntrusionSnapshots.entry("gate-story", env),
            "gate-unlocked": IntrusionSnapshots.entry("gate-unlocked", env),
            "gallery": SnapshotEntry(view: AnyView(DesignGallery()), size: CGSize(width: 1280, height: 1960)),
            "home": SnapshotEntry(view: AnyView(HomeBoard(summary: .sample, now: SnapshotFixtures.morning)), size: CGSize(width: 980, height: 1080)),
            // Late evening with the streak unearned: the oxblood risk flood, Tena nagging (fists, no word).
            "home-risk": SnapshotEntry(view: AnyView(HStack(spacing: 0) { SidebarView(selection: .constant(.home), summary: .sample); HomeBoard(summary: .sample, now: SnapshotFixtures.evening) }), size: CGSize(width: 1908, height: 952)),
            "home-first-run": SnapshotEntry(view: AnyView(HomeBoard(summary: .firstRun, now: SnapshotFixtures.morning)), size: CGSize(width: 980, height: 1080)),
            "main": SnapshotEntry(view: AnyView(HStack(spacing: 0) { SidebarView(selection: .constant(.home), summary: .sample); HomeBoard(summary: .sample, now: SnapshotFixtures.morning) }), size: CGSize(width: 1220, height: 1080)),
            // A wide desktop window (1908 x 980 incl. title bar).
            "main-wide": SnapshotEntry(view: AnyView(HStack(spacing: 0) { SidebarView(selection: .constant(.home), summary: .sample); HomeBoard(summary: .sample, now: SnapshotFixtures.morning) }), size: CGSize(width: 1908, height: 952)),
            "mascot-gallery": SnapshotEntry(view: AnyView(MascotGallery()), size: CGSize(width: 1660, height: 1440)),
            "mascot-qa": SnapshotEntry(view: AnyView(MascotQA()), size: CGSize(width: 1080, height: 1340)),
            "onboarding-1": SnapshotEntry(view: AnyView(OnboardingFlow(page: .welcome, hatched: false, plan: .constant(OnboardingPlan()))), size: CGSize(width: 760, height: 600)),
            "onboarding-1-hatched": SnapshotEntry(view: AnyView(OnboardingFlow(page: .welcome, hatched: true, plan: .constant(OnboardingPlan()))), size: CGSize(width: 760, height: 600)),
            "onboarding-2": SnapshotEntry(view: AnyView(OnboardingFlow(page: .intrusions, hatched: true, plan: .constant(OnboardingPlan()))), size: CGSize(width: 760, height: 600)),
            "onboarding-3": SnapshotEntry(view: AnyView(OnboardingFlow(page: .minimum, hatched: true, plan: .constant(OnboardingPlan()))), size: CGSize(width: 760, height: 600)),
            "onboarding-4": SnapshotEntry(view: AnyView(OnboardingFlow(page: .plan, hatched: true, plan: .constant(OnboardingPlan()))), size: CGSize(width: 760, height: 600)),
            "review-checkpoint": SnapshotEntry(view: AnyView(ReviewBoard(state: .checkpoint, typed: .constant(""), now: SnapshotFixtures.morning)), size: CGSize(width: 980, height: 760)),
            "review-correct": SnapshotEntry(view: AnyView(ReviewBoard(state: .correct, typed: .constant(""), now: SnapshotFixtures.morning)), size: CGSize(width: 980, height: 760)),
            "review-done": SnapshotEntry(view: AnyView(ReviewBoard(state: .done, typed: .constant(""), now: SnapshotFixtures.morning)), size: CGSize(width: 980, height: 760)),
            "review-question": SnapshotEntry(view: AnyView(ReviewBoard(state: .question, typed: .constant("levera"), now: SnapshotFixtures.morning)), size: CGSize(width: 980, height: 760)),
            "review-waiting": SnapshotEntry(view: AnyView(ReviewBoard(state: .waiting, typed: .constant(""), now: SnapshotFixtures.morning)), size: CGSize(width: 980, height: 760)),
            "review-wrong": SnapshotEntry(view: AnyView(ReviewBoard(state: .wrong, typed: .constant("asume"), now: SnapshotFixtures.morning)), size: CGSize(width: 980, height: 760)),
            "write": SnapshotEntry(view: AnyView(WriteBoard(prompt: TodaySummary.sample.write, text: .constant("Last week we had a planning meeting with the supply team. Although I was nervous, I managed to explain the dashboard based on real data."))), size: CGSize(width: 760, height: WriteBoard.height(for: TodaySummary.sample.write))),
            "write-done": SnapshotEntry(view: AnyView(WriteBoard(prompt: TodaySummary.sample.write, text: .constant(""), result: WriteResult(xp: 34, dayQualified: true, words: 24))), size: CGSize(width: 760, height: WriteBoard.height(for: TodaySummary.sample.write))),
            "write-text": SnapshotEntry(view: AnyView(WriteBoard(prompt: TodaySummary.textSample, text: .constant(""))), size: CGSize(width: 760, height: WriteBoard.height(for: TodaySummary.textSample))),
            "popover": SnapshotEntry(view: AnyView(MenuPopover(state: PopoverState(.sample, pausedUntil: nil))), size: CGSize(width: 360, height: 540)),
            "popover-first-run": SnapshotEntry(view: AnyView(MenuPopover(state: PopoverState(.firstRun, pausedUntil: SnapshotFixtures.morning.addingTimeInterval(3600)))), size: CGSize(width: 360, height: 540)),
            "placement-intro": SnapshotEntry(view: ExamSnapshots.placementIntro(env), size: CGSize(width: 1180, height: 960)),
            "achievements": SnapshotEntry(view: AnyView(ProgressSnapshot(screen: .achievements, vocab: env.content.vocab)), size: CGSize(width: 1100, height: 1640)),
            "knowledge-card": SnapshotEntry(view: AnyView(ProgressSnapshot(screen: .knowledgeCard, vocab: env.content.vocab)), size: CGSize(width: 940, height: 820)),
            "library": SnapshotEntry(view: AnyView(ProgressSnapshot(screen: .library, vocab: env.content.vocab)), size: CGSize(width: 1100, height: 1260)),
            "quests": SnapshotEntry(view: AnyView(ProgressSnapshot(screen: .quests, vocab: env.content.vocab)), size: CGSize(width: 1100, height: 1000)),
            "weekly-review": SnapshotEntry(view: AnyView(ProgressSnapshot(screen: .weeklyReview, vocab: env.content.vocab)), size: CGSize(width: 1100, height: 1480)),
            "overlay-poster": IntrusionSnapshots.entry("overlay-poster", env),
            "overlay-sticker": IntrusionSnapshots.entry("overlay-sticker", env),
            "overlay-wrong": IntrusionSnapshots.entry("overlay-wrong", env),
            "preannounce": IntrusionSnapshots.entry("preannounce", env),
            "settings-intrusions": IntrusionSnapshots.entry("settings-intrusions", env),
            "settings-safety": IntrusionSnapshots.entry("settings-safety", env),
        ]
        // Tena alone on a transparent background (`tena-happy`, `tena-focused`...), for design mockups.
        for mood in TenaMood.allCases {
            all["tena-\(mood.rawValue)"] = SnapshotEntry(view: AnyView(TenaView(mood: mood, stage: .juvenile, size: 520, word: "levera")), size: CGSize(width: 520, height: 520))
            // App icon layer: 2048 px, no floor shadow (Icon Composer draws its own).
            all["icon-tena-\(mood.rawValue)"] = SnapshotEntry(view: AnyView(TenaView(mood: mood, stage: .juvenile, size: 1024, ground: false)), size: CGSize(width: 1024, height: 1024))
            // The live Dock icon for each mood (yellow flood).
            all["app-icon-\(mood.rawValue)"] = SnapshotEntry(view: AnyView(AppIconArt(mood: mood)), size: CGSize(width: 512, height: 512))
        }
        // Nagging as Home shows her today: no due word is wired yet, so she drops the card for fists.
        all["tena-nagging-noword"] = SnapshotEntry(view: AnyView(TenaView(mood: .nagging, stage: .juvenile, size: 520)), size: CGSize(width: 520, height: 520))
        all["app-icon-good"] = SnapshotEntry(view: AnyView(AppIconArt(mood: .proud, flood: .good)), size: CGSize(width: 512, height: 512))
        all["app-icon-risk"] = SnapshotEntry(view: AnyView(AppIconArt(mood: .nagging, flood: .risk)), size: CGSize(width: 512, height: 512))
        return all
    }
}
