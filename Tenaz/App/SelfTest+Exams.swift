import Foundation
import TenazCore

/// Exam and grading self-tests (`--tenaz-selftest placement-sim | claude`).
extension SelfTest {
    /// A Rasch learner at theta 0.0 (truth band 4.0) takes the placement on a throwaway in-memory
    /// database, with simulated grading. Seed 1 is printed in full; 50 seeds give the hit rate.
    /// Passes when at least 70% of runs land within ±0.5 of the truth and none land above it.
    static func placementSimulation(environment env: AppEnvironment) async -> Int32 {
        guard let blueprint = env.blueprints.blueprint(for: .placement) else {
            print("placement-sim: no placement blueprint")
            return 1
        }
        do {
            let theta = 0.0
            let first = try await PlacementSimulation.run(theta: theta, seed: 1, blueprint: blueprint, library: env.content)
            print("placement-sim truth theta \(theta) band \(first.truthBand); \(first.taskCount) tasks, nominal \(Int(first.nominalMinutes)) min")
            print("seed 1, objective parts (pending: \(first.pendingBeforeGrading.map(\.rawValue).joined(separator: ", "))):")
            for s in first.objective {
                print(String(format: "  %@ band %.1f range %.1f-%.1f theta %+.2f sd %.2f (%.1f/%.0f right)%@",
                             pad(s.skill.rawValue), s.band, s.range.lowerBound, s.range.upperBound, s.estimate.mean, s.estimate.sd,
                             s.correct, s.total, s.pending ? " grade pending" : ""))
            }
            print("seed 1, after simulated grading:")
            for skill in ExamSkill.allCases {
                guard let e = first.final[skill] else { continue }
                print(String(format: "  %@ band %.1f theta %+.2f sd %.2f", pad(skill.rawValue), e.band, e.mean, e.sd))
            }
            print(String(format: "  overall   band %.1f (%.1f-%.1f), recorded %@", first.overall.band, first.overall.low,
                         first.overall.high, first.recordedOverall.map { String($0) } ?? "none"))

            var hits = 0
            var above = 0
            var histogram: [Double: Int] = [:]
            let seeds = UInt64(1)...50
            for seed in seeds {
                let r = try await PlacementSimulation.run(theta: theta, seed: seed, blueprint: blueprint, library: env.content)
                if r.withinHalfBand { hits += 1 }
                if r.overall.band > r.truthBand + 0.5 { above += 1 }
                histogram[r.overall.band, default: 0] += 1
            }
            let spread = histogram.keys.sorted().map { "\($0): \(histogram[$0] ?? 0)" }.joined(separator: ", ")
            print("50 seeds: \(hits)/50 within ±0.5 of \(first.truthBand), \(above) above; overall bands {\(spread)}")
            let ok = hits * 10 >= seeds.count * 7 && above == 0
            print(ok ? "placement-sim OK" : "placement-sim FAIL")
            return ok ? 0 : 1
        } catch {
            print("placement-sim error: \(error)")
            return 1
        }
    }

    private static func pad(_ s: String) -> String { s.padding(toLength: 9, withPad: " ", startingAt: 0) }

    /// One real grading call through the `claude` CLI on a short fixture paragraph. Prints the decoded
    /// grade as JSON, or "unavailable" with the reason (never a failure: Claude is optional).
    static func claudeGrade(environment env: AppEnvironment) async -> Int32 {
        let request = GradeRequest(
            kind: .writing,
            taskPrompt: "Tell me about yourself in 60-80 words: your work and what you want to do in English this year.",
            response: """
            I am working as a data analyst in a pharma company since 2024. My job consist in automate reports \
            and help the supply team with dashboards. Is very interesting, but sometimes the meetings are long \
            and I don't participate so much because my English depends of the topic. This year I want to speak \
            more confident in meetings and write emails faster.
            """,
            learnerBand: 3.5)
        do {
            let result = try await CLIGradeRunner(cli: env.claude).grade(request)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            print(String(decoding: try encoder.encode(result), as: UTF8.self))
            let mean = Double(result.criteria.map(\.score).reduce(0, +)) / Double(max(result.criteria.count, 1))
            print(String(format: "claude grade OK: mean %.2f, %d errors", mean, result.errors.count))
        } catch {
            print("unavailable (\(error))")
        }
        return 0
    }
}
