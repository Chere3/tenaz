import SwiftUI

extension ExamRunner {
    /// A binding to one entry of a draft list (gaps, interview answers) that reads "" and drops
    /// writes once the entry is gone: handing an item in replaces the draft before SwiftUI has torn
    /// the old item's fields down, and a plain `$runner.draft.gaps[i]` then traps out of range.
    func slot(_ list: WritableKeyPath<ExamDraft, [String]>, _ index: Int) -> Binding<String> {
        Binding(
            get: { self.draft[keyPath: list][safe: index] ?? "" },
            set: { value in
                guard self.draft[keyPath: list].indices.contains(index) else { return }
                self.draft[keyPath: list][index] = value
            })
    }
}
