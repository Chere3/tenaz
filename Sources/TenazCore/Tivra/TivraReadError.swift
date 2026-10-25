import Foundation

public enum TivraReadError: Error, Equatable, Sendable {
    case missingFile
    /// Refuses the debug and smoke-test databases of Tivra by design.
    case forbiddenDatabase
    case schemaMismatch(String)
}
