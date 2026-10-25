import Foundation

/// Scores a finished session: objective units into the skill posteriors at the attempt's weight,
/// writing/speaking into pending Claude grades (empty ones score 0 locally, so skipping isn't free).
public enum ExamScorer {
    public static func score(_ session: ExamSession) -> ExamOutcome {
        let weight = session.blueprint.kind.evidenceWeight
        var estimates = Dictionary(uniqueKeysWithValues: ExamSkill.allCases.map { ($0, session.priors[$0] ?? AbilityEstimator()) })
        var tally: [ExamSkill: (right: Double, total: Double)] = [:]
        var pending: [PendingGrade] = []
        var scores: [TaskScore] = []
        let fallbacks = Dictionary(session.blueprint.sections.map { ($0.id, $0.fallback) }, uniquingKeysWith: { a, _ in a })

        func record(_ units: [ScoredUnit]) {
            for unit in units {
                estimates[unit.skill]?.apply(unit, weight: weight)
                var t = tally[unit.skill] ?? (0, 0)
                t.total += unit.weight
                if unit.isCorrect { t.right += unit.weight }
                tally[unit.skill] = t
            }
        }

        for task in session.tasks {
            let answer = session.response(for: task.id)?.answer
            switch task.scoring {
            case let .claude(kind):
                let text = responseText(task, answer)
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    record([ScoredUnit(taskId: task.id, skill: task.skill, difficulty: task.difficulty, guessing: 0, weight: 1, outcome: .rubric(0))])
                    scores.append(TaskScore(taskId: task.id, sectionId: task.sectionId, skill: task.skill, correct: false, scoreRaw: 0, scoreMax: 5, source: "local"))
                } else {
                    let prompt = task.item.map(GradingRubric.taskPrompt(for:)) ?? ""
                    pending.append(PendingGrade(taskId: task.id, skill: task.skill, kind: kind, prompt: prompt, text: text,
                                                typed: kind == .speaking && fallbacks[task.sectionId] == .typed))
                    if tally[task.skill] == nil { tally[task.skill] = (0, 0) }
                    scores.append(TaskScore(taskId: task.id, sectionId: task.sectionId, skill: task.skill, correct: nil, scoreRaw: nil, scoreMax: 5, source: "claude"))
                }
            case .objective, .wordErrorRate:
                let units = ObjectiveScorer.units(for: task, answer: answer)
                record(units)
                let isRubric = task.scoring == .wordErrorRate
                let raw: Double = isRubric
                    ? units.compactMap { if case let .rubric(s) = $0.outcome { s } else { nil } }.reduce(0, +)
                    : Double(units.filter(\.isCorrect).count)
                scores.append(TaskScore(taskId: task.id, sectionId: task.sectionId, skill: task.skill,
                                        correct: units.allSatisfy(\.isCorrect), scoreRaw: raw,
                                        scoreMax: isRubric ? 5 : Double(units.count), source: isRubric ? "wer" : "objective"))
            }
        }

        let skills = ExamSkill.allCases.compactMap { skill -> SkillOutcome? in
            guard let t = tally[skill], let estimate = estimates[skill] else { return nil }
            return SkillOutcome(skill: skill, estimate: estimate, correct: t.right, total: t.total,
                                pending: pending.contains { $0.skill == skill })
        }
        return ExamOutcome(attemptId: session.id, kind: session.blueprint.kind, skills: skills, estimates: estimates,
                           overall: OverallBand(estimates: estimates), pending: pending, taskScores: scores)
    }

    /// Interview answers are labelled with their questions so Claude can judge topic development.
    static func responseText(_ task: ExamTask, _ answer: ExamAnswer?) -> String {
        guard let answer else { return "" }
        if case let .texts(list) = answer, let questions = task.item?.interviewQuestions {
            return zip(questions, list)
                .filter { !$0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { "Q: \($0.0)\nA: \($0.1)" }
                .joined(separator: "\n\n")
        }
        return answer.freeText
    }
}
