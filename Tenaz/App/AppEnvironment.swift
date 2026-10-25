import Foundation
import Observation
import TenazCore

/// App-wide services, built once at launch and injected through the SwiftUI environment.
@Observable
final class AppEnvironment {
    let paths: Paths
    let database: TenazDatabase?
    let content: ContentLibrary
    let contentProblems: [String]
    let blueprints: BlueprintCatalog
    let claude: ClaudeCLI
    /// XP, streak, Tena, penalties, quests, achievements (nil only if the database failed to open).
    let gamification: GamificationEngine?
    /// FSRS review sessions and today's set.
    let reviewStore: ReviewStore?
    /// The process's one Claude grading queue (started by AppDelegate on a normal launch only).
    let grading: GradingService

    init(inMemory: Bool = false) {
        paths = Paths.forApp(bundleIdentifier: Bundle.main.bundleIdentifier)
        database = inMemory ? (try? TenazDatabase.inMemory()) : (try? TenazDatabase.onDisk(paths))
        let root = Bundle.main.resourceURL!.appendingPathComponent("Content")
        let loaded = (try? ContentLibrary.load(from: root)) ?? ContentLibrary(vocab: [], items: [])
        (content, contentProblems) = ContentValidator.cleaned(loaded)
        blueprints = (try? BlueprintCatalog.load(from: root)) ?? BlueprintCatalog(blueprints: [])
        claude = ClaudeCLI(workDirectory: paths.claudeWorkDirectory)
        grading = GradingService(database: database, cli: claude)
        gamification = database.flatMap { try? GamificationEngine.bundled(database: $0, contentRoot: root) }
        reviewStore = database.map { ReviewStore(database: $0) }
        if let database {
            do { try ContentImporter.importVocab(content.vocab, into: database, now: Date()) } catch { NSLog("Tenaz: content import failed: \(error)") }
        }
    }
}
