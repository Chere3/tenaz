import Foundation

/// The bundled blueprints, one per exam kind.
public struct BlueprintCatalog: Codable, Sendable {
    public var blueprints: [ExamBlueprint]

    public init(blueprints: [ExamBlueprint]) { self.blueprints = blueprints }

    /// Reads `config/blueprints.json` under a folder laid out like `Content/`.
    public static func load(from contentRoot: URL) throws -> BlueprintCatalog {
        let url = contentRoot.appendingPathComponent("config/blueprints.json")
        do { return try JSONDecoder().decode(BlueprintCatalog.self, from: Data(contentsOf: url)) } catch {
            throw ContentError.decode(file: "config/blueprints.json", underlying: String(describing: error))
        }
    }

    public func blueprint(for kind: ExamKind) -> ExamBlueprint? { blueprints.first { $0.kind == kind } }
}
