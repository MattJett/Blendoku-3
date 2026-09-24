import SwiftUI

/// Which hundred to play.
///
/// Depth carries each arc's standing, so nothing else has to. A finished arc
/// is pressed into the page like a stamp, grey, its name kept. The one being
/// played is the only card with colour in it. The ones ahead stand up like
/// any other control but are grey, and their names are withheld — present,
/// pressable, and not yet saying what they are.
@MainActor
struct ChromarcSelectView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ProgressStore.self) private var progress

    /// The arc that most recently answered "not yet", and a nudge counter to
    /// shake it with.
    @State private var refused: Int?
    @State private var refusals = 0

    private var standings: [Int: Chromarc.Standing] {
        Chromarc.standings { progress.completed(in: $0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Arcs",
                         eyebrow: "\(String(format: "%02d", Chromarc.all.count)) Chromarcs") {
                router.pop()
            }

            ScrollView {
                VStack(spacing: Theme.Space.base) {
                    ForEach(Chromarc.all) { arc in
                        card(arc, standing: standings[arc.number] ?? .locked)
                    }
                }
                .padding(.horizontal, Theme.Space.margin)
                .padding(.vertical, Theme.Space.base)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            router.backdropPalette = Chromarc.first.previewRamp(steps: 5)
        }
    }

    // MARK: - Cards

    private func card(_ arc: Chromarc, standing: Chromarc.Standing) -> some View {
        let solved = progress.completed(in: arc)

        return Button {
            open(arc, standing: standing)
        } label: {
            VStack(alignment: .leading, spacing: Theme.Space.tight) {
                HStack(alignment: .firstTextBaseline) {
                    MonoLabel("Chromarc \(String(format: "%02d", arc.number))")
                    Spacer(minLength: 0)
                    MonoLabel(caption(standing), tint: standing == .current ? Theme.accent : Theme.textTertiary)
                }

                name(arc, standing: standing)

                bar(arc, standing: standing, solved: solved)

                HStack {
                    MonoLabel(standing == .locked ? "Locked" : "\(String(format: "%03d", solved)) / \(DifficultyCurve.levelCount)")
                    Spacer(minLength: 0)
                    if refused == arc.number {
                        MonoLabel(lockReason(arc), tint: Theme.textSecondary)
                            .transition(.opacity)
                    }
                }
            }
            .padding(Theme.Space.base)
            .frame(maxWidth: .infinity, alignment: .leading)
            .saturation(standing == .current ? 1 : 0)
            .opacity(standing == .current ? 1 : 0.55)
        }
        .buttonStyle(SlabButtonStyle(depth: 12, radius: Theme.Radius.panel, isOn: standing == .done))
        .modifier(Nudge(trigger: refused == arc.number ? refusals : 0))
        .accessibilityIdentifier("arcs.\(arc.number)")
        .accessibilityLabel(spokenLabel(arc, standing: standing, solved: solved))
    }

    @ViewBuilder
    private func name(_ arc: Chromarc, standing: Chromarc.Standing) -> some View {
        if standing == .locked {
            // Redacted rather than dashed out: a bar per word, as long as the
            // word, so the shape of a name is there without the name.
            HStack(spacing: 8) {
                ForEach(Array(arc.title.split(separator: " ").enumerated()), id: \.offset) { _, word in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Theme.textTertiary.opacity(0.45))
                        .frame(width: CGFloat(word.count) * 15, height: 22)
                }
            }
            .frame(height: 34, alignment: .leading)
            .accessibilityHidden(true)
        } else {
            Text(arc.title)
                .font(Theme.display(34))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(Theme.textPrimary)
                .frame(height: 34, alignment: .leading)
        }
    }

    /// The arc's colours with the unsolved part cut back to the page.
    private func bar(_ arc: Chromarc, standing: Chromarc.Standing, solved: Int) -> some View {
        let fraction = standing == .done ? 1 : Double(solved) / Double(DifficultyCurve.levelCount)
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                SoftSurface(shape: RoundedRectangle(cornerRadius: 5, style: .continuous),
                            depth: 4, pressed: true)
                if standing != .locked {
                    GradientRibbon(colours: arc.previewRamp(steps: 24), height: 12, radius: 4)
                        .frame(width: max(12, proxy.size.width * fraction))
                }
            }
        }
        .frame(height: 12)
    }

    private func caption(_ standing: Chromarc.Standing) -> String {
        switch standing {
        case .done: "Complete"
        case .current: "Playing"
        case .locked: "—"
        }
    }

    private func lockReason(_ arc: Chromarc) -> String {
        arc.isPlayable ? "Finish the one before" : "Still being made"
    }

    private func spokenLabel(_ arc: Chromarc, standing: Chromarc.Standing, solved: Int) -> String {
        let number = "Chromarc \(arc.number)"
        switch standing {
        case .done: return "\(number), \(arc.title), complete"
        case .current: return "\(number), \(arc.title), \(solved) of \(DifficultyCurve.levelCount) solved"
        case .locked: return "\(number), locked"
        }
    }

    // MARK: - Opening

    private func open(_ arc: Chromarc, standing: Chromarc.Standing) {
        switch standing {
        case .done, .current:
            Haptics.play(.select)
            router.push(.levels)
        case .locked:
            // Raised, so it answers a press — with a no, a shake, and why.
            Haptics.play(.reject)
            withAnimation(Motion.quick) {
                refused = arc.number
                refusals += 1
            }
        }
    }
}

/// One short sideways shake: the card saying no.
@MainActor
private struct Nudge: ViewModifier {
    let trigger: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, offset in
            view.offset(x: offset)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(-7, duration: 0.05)
                CubicKeyframe(6, duration: 0.07)
                CubicKeyframe(-3, duration: 0.07)
                CubicKeyframe(0, duration: 0.06)
            }
        }
    }
}
