import SwiftUI
import TenazCore

/// The learner's Contract (F10): the rules they choose, all OFF by default, each explained, with costs,
/// caps, pending changes, Mercy tokens and the experiment log. Tightening starts at 04:00;
/// loosening waits 24 hours. Hatches (kill switch, Pause 1 h, quiet hours) are not part of it.
struct ContractRoot: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: ContractModel?

    var body: some View {
        ScrollView {
            if let model {
                ContractPage(model: model)
                    .padding(Tokens.Space.xl)
                    .frame(maxWidth: 980, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .paperBackground()
        .onAppear {
            let m = model ?? ContractModel(engine: env.gamification)
            m.load()
            model = m
        }
    }
}
