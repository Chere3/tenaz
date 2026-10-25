/// A data-driven exam definition (`Content/config/blueprints.json`).
public struct ExamBlueprint: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var kind: ExamKind
    public var title: String
    public var sections: [SectionSpec]

    /// Nominal length if every section runs to its limit (only one routed module counts).
    public var nominalMinutes: Double {
        sections.filter { $0.resolvedStage != .upper }.map(\.minutes).reduce(0, +)
    }
}
