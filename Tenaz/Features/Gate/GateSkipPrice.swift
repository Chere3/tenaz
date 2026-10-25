/// What the emergency skip costs right now (only under Response cost; never refused).
struct GateSkipPrice: Equatable {
    var responseCostOn: Bool
    var mercyLeft: Int

    var full: Int { responseCostOn ? 20 : 0 }
    var withMercy: Int { responseCostOn && mercyLeft > 0 ? 10 : full }

    var short: String { responseCostOn ? "−20 Vitality" : "free" }
}
