import SwiftUI

// MARK: - Carving

/// Lettering pressed into the page.
///
/// The app's one rule for depth is that anything lifted can be pressed. Type
/// that is not a control therefore never stands up off the ground; the big
/// pieces — the wordmark, the screen titles — are cut *into* it instead.
@MainActor
struct Carved: ViewModifier {
    enum Strength {
        /// Barely there: ground-coloured letters read by their edges alone.
        /// For the wordmark, which is decoration and names itself to
        /// VoiceOver separately.
        case whisper
        /// Inked in the recess, so it reads at a glance. For titles.
        case stamp
    }

    var strength: Strength = .stamp
    var tint: Color?

    @Environment(\.colorSchemeContrast) private var contrast

    private var fill: Color {
        if let tint { return tint }
        switch strength {
        case .whisper: return Theme.carveFill
        case .stamp: return Theme.textPrimary.opacity(0.84)
        }
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if contrast == .increased {
            // Relief trades contrast for calm. Someone who has asked the
            // system for more contrast gets the letters flat and solid.
            content.foregroundStyle(tint ?? Theme.textPrimary)
        } else {
            content
                .foregroundStyle(fill)
                .shadow(color: Theme.carveShade, radius: 0.5, x: -0.7, y: -1)
                .shadow(color: Theme.carveLight, radius: 0.5, x: 0.7, y: 1)
        }
    }
}

extension View {
    @MainActor
    func carved(_ strength: Carved.Strength = .stamp, tint: Color? = nil) -> some View {
        modifier(Carved(strength: strength, tint: tint))
    }
}

// MARK: - Wordmark

/// SWATCH across, WORD down, sharing the W — the name set as the crossword it
/// is. One letter doing two jobs is also exactly what a tile does on a board
/// where two blends cross.
///
/// Every letter sits centred in an equal cell, so the down word stays locked
/// under the W however the compressed face spaces its letters.
@MainActor
struct Wordmark: View {
    /// The side of one crossword cell. The whole mark is six cells wide and
    /// four tall, so this is the only size it needs.
    var cell: CGFloat = 40
    /// Inlays the shared W in the accent. Used once, on the title page.
    var marksCrossing = false

    private static let across = Array("SWATCH")
    private static let down = Array("ORD")
    /// The W, second letter across, is where the words cross.
    private static let crossing = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(Self.across.enumerated()), id: \.offset) { index, letter in
                    glyph(letter, isCrossing: index == Self.crossing)
                }
            }
            ForEach(Array(Self.down.enumerated()), id: \.offset) { _, letter in
                glyph(letter, isCrossing: false)
                    .padding(.leading, cell * CGFloat(Self.crossing))
            }
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Swatchword")
        .accessibilityAddTraits(.isHeader)
    }

    private func glyph(_ letter: Character, isCrossing: Bool) -> some View {
        Text(String(letter))
            .font(Theme.display(cell * 1.04, weight: .black))
            .carved(.whisper, tint: isCrossing && marksCrossing ? Theme.accent : nil)
            .frame(width: cell, height: cell * 0.92)
    }
}

// MARK: - Micro type

/// Monospaced micro-caps: the instrument-panel annotation. Version numbers,
/// counters, coordinates — anything that is data rather than prose.
@MainActor
struct MonoLabel: View {
    let text: String
    var size: CGFloat = 9
    var tint: Color = Theme.textTertiary
    var weight: Font.Weight = .medium

    init(_ text: String, size: CGFloat = 9, tint: Color = Theme.textTertiary,
         weight: Font.Weight = .medium) {
        self.text = text
        self.size = size
        self.tint = tint
        self.weight = weight
    }

    var body: some View {
        Text(text.uppercased())
            .font(Theme.mono(size, weight: weight))
            .tracking(size * 0.22)
            .foregroundStyle(tint)
            .lineLimit(1)
    }
}

/// A micro-label turned on its side to run up the edge of something.
@MainActor
struct VerticalLabel: View {
    let text: String
    /// Reads top to bottom when true, bottom to top when false.
    var descending = true

    var body: some View {
        MonoLabel(text, size: 8)
            .fixedSize()
            .rotationEffect(.degrees(descending ? 90 : -90))
            .frame(width: 12)
            .frame(maxHeight: .infinity)
            .accessibilityHidden(true)
    }
}

/// The build, set as a registration mark in the corner of the page. Printed
/// straight onto the ground: it is information, not a control, so it gets no
/// surface of its own.
@MainActor
struct VersionMark: View {
    var body: some View {
        MonoLabel("V\(Runtime.version) · \(Runtime.build)", size: 8)
            .opacity(0.8)
            .accessibilityLabel("Version \(Runtime.version), build \(Runtime.build)")
    }
}
