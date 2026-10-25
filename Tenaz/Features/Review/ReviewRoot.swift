import SwiftUI

/// The review session screen (PLAN F3/F4 E1-E7, M3): live wrapper around `ReviewBoard`.
struct ReviewRoot: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(Navigator.self) private var navigator
    @Environment(TodayModel.self) private var today
    @State private var model: ReviewModel?

    var body: some View {
        Group {
            if let model {
                @Bindable var model = model
                ReviewBoard(state: model.state, typed: $model.typed, actions: ReviewActions(
                    choose: model.choose, submit: model.submit, reveal: model.reveal, next: { model.next() },
                    stop: model.stop, write: write, home: home
                ))
            } else {
                ReviewBoard(state: ReviewViewState(phase: .loading), typed: .constant(""))
            }
        }
        .onAppear(perform: begin)
    }

    private func begin() {
        guard model == nil else { return }
        let session = ReviewModel(env: env)
        session.onFinish = finished
        model = session
        session.start()
    }

    private func finished(answered: Int) {
        today.syncLearning()
        if answered == 0 { home() }
    }

    private func write() {
        navigator.showWrite = true
    }

    private func home() {
        navigator.route = .home
    }
}
