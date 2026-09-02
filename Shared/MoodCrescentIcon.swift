import SwiftUI

/// PRD §8: "月牙/嘴角造型" icon — a color dot with a crescent bite taken out
/// vertically. Direction/thickness per level lives on MoodLevel
/// (crescentEraseDirection/crescentOffsetFraction) — confirmed against the
/// reference art, see that property's doc comment before changing it.
/// Sliver thickness encodes intensity (thin at the two extremes), independent
/// of color, so it still reads on the lock screen where the system forces
/// monochrome rendering (§6/§11). The "bitten" area isn't erased to
/// transparency — it stays the same hue at lower opacity, so the full circle
/// silhouette is always visible and the icon never depends on matching
/// whatever backdrop it sits on.
///
/// `glossy` swaps the flat fill for a layered sphere-shaded one (radial
/// gradient + multiply core-shadow + two highlights), clipped to the exact
/// same crescent silhouette via `.mask(_:)` instead of the flat variant's
/// inline `.blendMode(.destinationOut)` — the two produce identical alpha
/// shapes, mask just lets the glossy content carry its own internal blend
/// modes without fighting the crescent-cutting blend mode in one group.
/// Defaults to false everywhere it isn't explicitly requested, so existing
/// call sites (history rows, detail header, both widgets) render unchanged;
/// widgets in particular should stay on the flat variant — WidgetKit's
/// snapshot rendering doesn't reliably support blur/multiply layering.
struct MoodCrescentIcon: View {
    let level: MoodLevel
    let size: CGFloat
    var glossy: Bool = false

    var body: some View {
        ZStack {
            Circle().fill(level.color.opacity(0.28))
            if level.crescentOffsetFraction > 0 {
                fill.mask(crescentMask)
            } else {
                fill
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var fill: some View {
        if glossy {
            glossyFill
        } else {
            Circle().fill(level.color)
        }
    }

    private var crescentMask: some View {
        ZStack {
            Circle().fill(.black)
            Circle()
                .fill(.black)
                .offset(y: size * level.crescentOffsetFraction * level.crescentEraseDirection)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
    }

    private var glossyFill: some View {
        ZStack {
            RadialGradient(
                colors: [level.color.opacity(0.75), level.color],
                center: UnitPoint(x: 0.32, y: 0.28),
                startRadius: 0,
                endRadius: size * 0.75
            )
            RadialGradient(
                colors: [Color.black.opacity(0.3), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: size * 0.85
            )
            .blendMode(.multiply)
            Ellipse()
                .fill(Color.white.opacity(0.4))
                .frame(width: size * 0.4, height: size * 0.26)
                .blur(radius: max(size * 0.06, 1))
                .offset(x: -size * 0.16, y: -size * 0.18)
            Ellipse()
                .fill(Color.white.opacity(0.85))
                .frame(width: size * 0.1, height: size * 0.07)
                .blur(radius: 0.5)
                .offset(x: -size * 0.2, y: -size * 0.23)
        }
        .clipShape(Circle())
    }
}
