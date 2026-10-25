/// The tiny structured answer the connection test asks Claude for.
nonisolated struct ClaudePing: Decodable, Sendable {
    let ok: Bool
}
