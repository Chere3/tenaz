import SwiftUI

/// What sits under an overlay in a snapshot: a muted desktop with a menu bar and two app windows,
/// plus the notification band the surfaces leave uncovered.
struct DesktopStandIn: View {
    var showBand = true

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(red: 0.16, green: 0.20, blue: 0.36), Color(red: 0.34, green: 0.27, blue: 0.40)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            fakeWindow.frame(width: 640, height: 430).offset(x: 90, y: 120)
            fakeWindow.frame(width: 560, height: 380).offset(x: 700, y: 330)
            Rectangle().fill(.black.opacity(0.35)).frame(height: 25)
            if showBand {
                VStack(spacing: 4) {
                    Image(systemName: "bell.badge").font(.system(size: 18, weight: .semibold))
                    Text("Notifications stay visible").font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: OverlayLayoutBand.width - 24, height: OverlayLayoutBand.height - 40)
                .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])) }
                .frame(maxWidth: .infinity, alignment: .topTrailing)
                .padding(.top, 37)
                .padding(.trailing, 12)
            }
        }
        .accessibilityHidden(true)
    }

    private var fakeWindow: some View {
        RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.10))
            .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.08)).frame(height: 30) }
            .clipShape(.rect(cornerRadius: 14))
    }
}
