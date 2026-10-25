@testable import TenazCore

/// A grader that returns canned results in turn, or throws the queued errors first.
actor FakeGradeRunner: GradeRunner {
    nonisolated let model = "fake"
    private var results: [GradeResult]
    private var errors: [ClaudeCLIError]
    private(set) var calls = 0
    private var served = 0

    init(results: [GradeResult], errors: [ClaudeCLIError] = []) {
        self.results = results
        self.errors = errors
    }

    func grade(_ request: GradeRequest) async throws -> GradeResult {
        calls += 1
        if !errors.isEmpty { throw errors.removeFirst() }
        defer { served += 1 }
        return results[served % results.count]
    }
}
