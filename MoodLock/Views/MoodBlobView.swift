import SwiftUI

/// Organic blob outline, traced from the "Soft Blob Mascot" design mockup's
/// SVG path (200x200 viewBox), normalized to a unit square so it scales to
/// any frame. This is a deliberate departure from PRD §8's "no illustrated
/// character" rule — the mascot direction the user explicitly asked for.
struct BlobShape: Shape {
    func path(in rect: CGRect) -> Path {
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x / 200 * rect.width, y: rect.minY + y / 200 * rect.height)
        }
        var path = Path()
        path.move(to: pt(100, 24))
        path.addCurve(to: pt(178, 88), control1: pt(138, 22), control2: pt(172, 48))
        path.addCurve(to: pt(118, 178), control1: pt(184, 130), control2: pt(160, 168))
        path.addCurve(to: pt(18, 130), control1: pt(76, 188), control2: pt(32, 170))
        path.addCurve(to: pt(56, 30), control1: pt(4, 90), control2: pt(18, 48))
        path.addCurve(to: pt(100, 24), control1: pt(70, 23), control2: pt(86, 25))
        path.closeSubpath()
        return path
    }
}

/// The homepage mascot: color follows the most recently logged mood (falls
/// back to neutral gray when there's no history yet). Shading is layered to
/// read as a squishy 3D sphere rather than a flat sticker — a radial base
/// gradient for form, a multiply-blended core shadow for volume at the
/// lower-right, and two highlights (a soft broad one plus a small sharp
/// "wet" glint) for glossiness. No eyes/mouth — kept abstract.
///
/// Poking it anywhere tilts and dents it right at that point (not just a
/// uniform bottom-anchored squash) — the scale/rotation anchor tracks the
/// touch location, and the 3D-tilt axis is computed perpendicular to the
/// vector from center to that point, so the surface reads as caving in at
/// wherever it was actually pressed. A low-damping spring on release lets it
/// overshoot past its resting shape before settling, which is what reads as
/// "Q弹" (bouncy jelly) rather than a generic press-scale.
struct MoodBlobView: View {
    let level: MoodLevel?
    var size: CGFloat = 180

    @State private var isPressed = false
    @State private var pokePoint: UnitPoint = .center

    private var baseColor: Color { level?.color ?? MoodLevel.neutral.color }

    /// Axis perpendicular to (pokePoint - center), so rotating around it
    /// tilts the surface away from the viewer right at the touch point.
    private var rotationAxis: (x: CGFloat, y: CGFloat, z: CGFloat) {
        let dx = pokePoint.x - 0.5
        let dy = pokePoint.y - 0.5
        let length = max((dx * dx + dy * dy).squareRoot(), 0.001)
        return (x: -dy / length, y: dx / length, z: 0)
    }

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.14))
                .frame(width: size * (isPressed ? 0.7 : 0.62), height: size * 0.12)
                .blur(radius: 6)
                .offset(y: size * 0.52)

            blobShape
                .frame(width: size, height: size)
                .scaleEffect(isPressed ? 0.82 : 1.0, anchor: pokePoint)
                .rotation3DEffect(
                    .degrees(isPressed ? 26 : 0),
                    axis: rotationAxis,
                    anchor: pokePoint,
                    perspective: 0.6
                )
                .animation(
                    isPressed ? .easeOut(duration: 0.08) : .spring(response: 0.5, dampingFraction: 0.26),
                    value: isPressed
                )
                .contentShape(BlobShape())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            pokePoint = UnitPoint(
                                x: min(max(value.location.x / size, 0), 1),
                                y: min(max(value.location.y / size, 0), 1)
                            )
                            isPressed = true
                        }
                        .onEnded { _ in isPressed = false }
                )
                .sensoryFeedback(.impact(weight: .light), trigger: isPressed) { _, newValue in newValue }
        }
    }

    private var blobShape: some View {
        BlobShape()
            .fill(
                RadialGradient(
                    colors: [baseColor.opacity(0.72), baseColor],
                    center: UnitPoint(x: 0.32, y: 0.28),
                    startRadius: 0,
                    endRadius: size * 0.75
                )
            )
            .overlay(
                ZStack {
                    // Core shadow: darkens the lower-right for volume.
                    RadialGradient(
                        colors: [Color.black.opacity(0.32), .clear],
                        center: .bottomTrailing,
                        startRadius: 0,
                        endRadius: size * 0.85
                    )
                    .blendMode(.multiply)

                    // Broad soft highlight.
                    Ellipse()
                        .fill(Color.white.opacity(0.35))
                        .frame(width: size * 0.38, height: size * 0.24)
                        .blur(radius: 6)
                        .offset(x: -size * 0.16, y: -size * 0.17)

                    // Small sharp glint on top of the broad highlight.
                    Ellipse()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: size * 0.09, height: size * 0.06)
                        .blur(radius: 0.5)
                        .offset(x: -size * 0.2, y: -size * 0.22)
                }
                .clipShape(BlobShape())
            )
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: baseColor)
    }
}

#Preview {
    VStack(spacing: 24) {
        MoodBlobView(level: .veryPleasant)
        MoodBlobView(level: nil)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
