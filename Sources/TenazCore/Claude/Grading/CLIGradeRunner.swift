/// Grades through the `claude` CLI (the learner's claude.ai session; never an API key).
public struct CLIGradeRunner: GradeRunner {
    public var cli: ClaudeCLI

    public init(cli: ClaudeCLI) { self.cli = cli }

    public var model: String { cli.model }

    public func grade(_ request: GradeRequest) async throws -> GradeResult {
        let result = try await cli.structured(
            GradeResult.self,
            prompt: GradingRubric.prompt(for: request),
            system: GradingRubric.system(for: request.kind),
            schema: GradingRubric.schema(for: request.kind)
        )
        try GradingRubric.validate(result, kind: request.kind)
        return result
    }
}
