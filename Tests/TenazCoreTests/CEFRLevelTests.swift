import Testing
@testable import TenazCore

@Test func levelsAreOrdered() {
    #expect(CEFRLevel.b1Plus > .b1)
    #expect(CEFRLevel.allCases.map(\.label).joined(separator: " ") == "A1 A2 B1 B1+ B2 B2+ C1 C2")
}
