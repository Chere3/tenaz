import Foundation

/// The typed part of an `ExamDraft`, kept in `exam_progress.notes` under "draft" so a resume
/// gives back what was written for the task on screen.
struct StoredDraft: Codable, Equatable {
    var taskId: String
    var text: String
    var texts: [String]
    var gaps: [String]

    var hasText: Bool {
        !text.isEmpty || texts.contains { !$0.isEmpty } || gaps.contains { !$0.isEmpty }
    }

    var encoded: String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)).map { String(decoding: $0, as: UTF8.self) }
    }

    static func decode(_ json: String) -> StoredDraft? {
        try? JSONDecoder().decode(StoredDraft.self, from: Data(json.utf8))
    }

    func apply(to draft: inout ExamDraft) {
        if !text.isEmpty { draft.text = text }
        if texts.count == draft.texts.count { draft.texts = texts }
        if gaps.count == draft.gaps.count { draft.gaps = gaps }
    }
}
