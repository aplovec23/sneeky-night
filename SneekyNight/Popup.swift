import SwiftUI

struct Popup {
    /// Each pop-up is its own card, so a button can only ever be pressed once.
    var id = UUID()
    var title: String
    var message: String
    var symbol: String
    var color: Color
    var button: String
    var action: () -> Void
    var secondButton: String? = nil
    var secondAction: () -> Void = {}
}

/// A big centred card, e.g. "You found a key!".
struct PopupView: View {
    let popup: Popup
    @State private var shown = false
    /// Set by the first tap. Tapping again while the card fades away does nothing (no more duplicate keys).
    @State private var used = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: popup.symbol)
                    .font(.system(size: 90, weight: .bold))
                    .foregroundStyle(popup.color)
                    .shadow(color: popup.color.opacity(0.8), radius: shown ? 22 : 0)
                    .rotationEffect(.degrees(shown ? -12 : 12))
                    .animation(.easeInOut(duration: 0.8).repeatForever(), value: shown)
                Text(popup.title)
                    .font(.game(52, .heavy))
                    .foregroundStyle(.white)
                Text(popup.message)
                    .font(.game(24, .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
                HStack(spacing: 20) {
                    if let second = popup.secondButton {
                        BigButton(title: second, color: .gray) { once(popup.secondAction) }
                    }
                    BigButton(title: popup.button) { once(popup.action) }
                }
                .padding(.top, 8)
            }
            .padding(44)
            .background(
                LinearGradient(colors: [Color(red: 0.25, green: 0.18, blue: 0.48), Color(red: 0.12, green: 0.10, blue: 0.30)],
                               startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 40)
            )
            .overlay(RoundedRectangle(cornerRadius: 40).stroke(Palette.gold.opacity(0.7), lineWidth: 4))
            .scaleEffect(shown ? 1 : 0.6)
            .opacity(shown ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.4, bounce: 0.4)) { shown = true }
        }
    }

    private func once(_ action: () -> Void) {
        guard !used else { return }
        used = true
        action()
    }
}
