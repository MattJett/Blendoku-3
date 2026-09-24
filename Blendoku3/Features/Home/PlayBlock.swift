import SwiftUI

/// The play button, which is also the arc's progress.
///
/// One raised block. Inside it the arc's own colours rise from the bottom as
/// levels are solved — darkest first, because that is the order the arc runs
/// in — and the word PLAY is set across the whole height. Where the colour has
/// reached, the lettering is knocked clean out of it; above the line it is
/// pressed into the page. So the word fills in, literally, with the colours
/// the player has earned.
///
/// The arc's number and name run up either side of it on the page itself,
/// since they label the block rather than being part of what gets pressed.
@MainActor
struct PlayBlock: View {
    enum Status: Equatable {
        case start, next, resume, complete
    }

    let arc: Chromarc
    let next: Int
    let solved: Int
    let status: Status
    let action: () -> Void

    private var total: Int { DifficultyCurve.levelCount }

    /// Never quite empty. At nothing solved the block would be a blank slab
    /// with a ghost of a word on it, which does not read as something to
    /// press; a foot of colour under it does.
    private var fill: Double { min(1, max(0.06, Double(solved) / Double(total))) }
    private var percent: Int { solved * 100 / max(total, 1) }

    private var ramp: [Color] {
        arc.previewRamp(steps: 18, lightness: 0.30...0.60).map(Color.init)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous)
    }

    var body: some View {
        HStack(spacing: 5) {
            VerticalLabel(text: "Chromarc \(String(format: "%02d", arc.number))", descending: false)
            Button(action: action) { face }
                .buttonStyle(Press(shape: shape))
                .accessibilityIdentifier("home.play")
                .accessibilityLabel(spokenLabel)
                .accessibilityHint(status == .complete ? "Opens the arcs" : "Opens the next board")
            VerticalLabel(text: arc.title, descending: true)
        }
    }

    // MARK: - Face

    private var face: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let word = min(proxy.size.width * 0.50, height * 0.40)

            ZStack {
                LinearGradient(colors: ramp, startPoint: .bottom, endPoint: .top)
                    .mask(alignment: .bottom) {
                        Rectangle().frame(height: height * fill)
                    }

                lettering(word: word, knockedOut: false)

                lettering(word: word, knockedOut: true)
                    .mask(alignment: .bottom) {
                        Rectangle().frame(height: height * fill)
                    }
            }
            .clipShape(shape)
        }
    }

    private func lettering(word: CGFloat, knockedOut: Bool) -> some View {
        let label = knockedOut ? Theme.knockout : Theme.textSecondary

        return VStack(spacing: 0) {
            HStack {
                MonoLabel(headline.leading, size: 9, tint: label, weight: .semibold)
                Spacer(minLength: 0)
                MonoLabel(headline.trailing, size: 9, tint: label, weight: .semibold)
            }
            Spacer(minLength: 0)
            Text("Play")
                .font(Theme.display(word, weight: .black))
                .textCase(.uppercase)
                .tracking(1)
                .lineLimit(1)
                .modifier(PlayLettering(knockedOut: knockedOut))
            Spacer(minLength: 0)
            HStack {
                MonoLabel("\(percent)%", size: 9, tint: label, weight: .semibold)
                Spacer(minLength: 0)
                MonoLabel("\(String(format: "%03d", solved)) / \(total)", size: 9, tint: label,
                          weight: .semibold)
            }
        }
        .padding(16)
        .accessibilityHidden(true)
    }

    private var headline: (leading: String, trailing: String) {
        switch status {
        case .start: ("Level \(String(format: "%03d", next))", "Start")
        case .next: ("Next \(String(format: "%03d", next))", "Continue")
        case .resume: ("Next \(String(format: "%03d", next))", "Resume")
        case .complete: ("All \(total)", "Complete")
        }
    }

    private var spokenLabel: String {
        switch status {
        case .complete:
            return "Play. \(arc.title) complete."
        case .resume:
            return "Resume level \(next). \(arc.title), \(percent) percent solved."
        case .start, .next:
            return "Play level \(next). \(arc.title), \(percent) percent solved."
        }
    }
}

/// The word itself: pressed into the page where the colour has not reached,
/// clean pale lettering where it has.
@MainActor
private struct PlayLettering: ViewModifier {
    let knockedOut: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if knockedOut {
            content.foregroundStyle(Theme.knockout)
        } else {
            content.carved(.whisper)
        }
    }
}

/// The block goes down under the finger like every other raised thing.
@MainActor
private struct Press: ButtonStyle {
    let shape: RoundedRectangle

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(shape)
            .softSurface(shape, depth: 16, pressed: configuration.isPressed)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}
