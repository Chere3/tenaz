import SwiftUI
import TenazCore

/// Wires the Library to the local stores: start a book, log reading, read Brain bites, pick words.
/// Works without the database too (recommendations from the cold start, nothing saved).
struct LibraryRoot: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model = LibraryModel()
    @State private var gloss: GlossIndex?
    @State private var reading: KnowledgeCard?
    @State private var logging: CatalogItem?
    @State private var picked: Set<String> = []

    private var content: LibraryContent { LibraryBundle.content }
    private var store: LibraryStore? { env.database.map { LibraryStore(database: $0) } }

    var body: some View {
        LibraryScreen(model: model,
                      start: start,
                      log: { logging = $0 },
                      openBrainBite: { reading = $0 })
            .task { load() }
            .sheet(item: $logging) { item in
                ReadingLogSheet(item: item, onSave: { save($0, for: item) }, onCancel: { logging = nil })
            }
            .sheet(item: $reading) { card in
                KnowledgeReader(card: card, gloss: gloss ?? GlossIndex(vocab: env.content.vocab),
                                goDeeper: content.item(card.goDeeper), picked: picked,
                                onPick: { entry in pick(entry, from: card) },
                                onSave: { answer in finish(card, answer: answer) },
                                onClose: { reading = nil })
            }
    }

    private func load() {
        if gloss == nil { gloss = GlossIndex(vocab: env.content.vocab) }
        guard let store else {
            model.reading = Recommender.pick(content.catalog, profile: .coldStart)
            model.brainBite = KnowledgeCard.brainBite(content.knowledge, read: [], day: DayBoundary.day(for: .now))
            return
        }
        do {
            // Recommend at the level of the latest placement or exam, not the fixed B1+ guess.
            let band = try ExamStore(database: store.database).currentBand()
            model = try LibraryModel.build(content: content, store: store, now: .now, band: band)
            picked = try store.pickedNoteIds()
        } catch { NSLog("Tenaz: library failed to load: \(error)") }
    }

    private func start(_ item: CatalogItem) {
        do { try store?.setStatus(item.id, .inProgress, now: .now) } catch { NSLog("Tenaz: start failed: \(error)") }
        load()
    }

    private func save(_ entry: ReadingLogEntry, for item: CatalogItem) {
        do {
            try store?.logReading(itemId: item.id, minutes: entry.minutes, pages: entry.pages,
                                  comprehension: ReadingCheck.comprehension(yes: entry.understood), now: .now)
            if let status = entry.newStatus { try store?.setStatus(item.id, status, reason: entry.abandonReason, now: .now) }
        } catch { NSLog("Tenaz: reading log failed: \(error)") }
        logging = nil
        load()
    }

    private func pick(_ entry: VocabEntry, from card: KnowledgeCard) {
        do { try store?.pick(noteId: entry.id, source: ReadingLogRecord.knowledgePrefix + card.id, now: .now) } catch {
            NSLog("Tenaz: pick failed: \(error)")
        }
        picked.insert(entry.id)
    }

    private func finish(_ card: KnowledgeCard, answer: String) {
        do { try store?.saveBrainBite(cardId: card.id, minutes: card.readingMinutes, answer: answer, now: .now) } catch {
            NSLog("Tenaz: brain bite failed: \(error)")
        }
        reading = nil
        load()
    }
}
