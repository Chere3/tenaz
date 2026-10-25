import SwiftUI

/// A calm, centered message between tasks (meeting pause, done, left).
struct ExamMessageView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: Tokens.Space.m) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(Tokens.brand)
            Text(title).font(Typography.displayM).foregroundStyle(Tokens.ink)
            Text(message)
                .font(Typography.body)
                .foregroundStyle(Tokens.ink)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
