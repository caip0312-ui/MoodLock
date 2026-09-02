import SwiftUI

/// One tap logs a mood entry immediately — this is a momentary action button,
/// not a persistent picker, so the "selected" glow (PRD §8) auto-reverts.
struct MoodButton: View {
    let level: MoodLevel
    let isPulsing: Bool
    var size: CGFloat = 52
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: size < 45 ? 5 : 8) {
                MoodCrescentIcon(level: level, size: size, glossy: true)
                    .overlay(
                        Circle()
                            .stroke(level.color, lineWidth: 3)
                            .scaleEffect(isPulsing ? 1.4 : 1.0)
                            .opacity(isPulsing ? 1 : 0)
                    )
                    .scaleEffect(isPulsing ? 1.15 : 1.0)
                Text(level.label)
                    .font(size < 45 ? .caption2 : .caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isPulsing)
        .accessibilityLabel(level.label)
    }
}
