/// Chip and badge states; each has its own glyph, so state never relies on colour alone.
enum ChipState: String, CaseIterable {
    case idle, active, done, locked
}
