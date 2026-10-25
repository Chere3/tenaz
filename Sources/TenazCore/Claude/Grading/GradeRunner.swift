/// Something that grades one response. The app uses `CLIGradeRunner`; tests use fakes.
public protocol GradeRunner: Sendable {
    var model: String { get }
    func grade(_ request: GradeRequest) async throws -> GradeResult
}
