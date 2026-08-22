import SwiftUI
import UIKit

/// The blends the player kept.
///
/// A shelf of finished work rather than a list of achievements: each entry is
/// the ribbon itself at a size worth looking at, with the level it came from
/// set small underneath. The colour is the content here, so this is the one
/// screen where the chrome gets furthest out of the way.
@MainActor
struct CollectionView: View {
    @Environment(AppRouter.self) private var router
    @Environment(BlendLibrary.self) private var library

    @State private var copied: UUID?

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Kept",
                         eyebrow: library.isEmpty ? "Nothing yet"
                                                  : "\(library.blends.count) blends") {
                router.pop()
            }

            if library.isEmpty {
                empty
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.Space.base) {
                        ForEach(library.blends) { blend in
                            entry(blend)
                        }
                    }
                    .padding(.horizontal, Theme.Space.margin)
                    .padding(.vertical, Theme.Space.base)
                }
            }
        }
    }

    private var empty: some View {
        VStack(spacing: Theme.Space.snug) {
            Spacer(minLength: 0)
            MoodLabel("Nothing kept yet")
            Text("Solve a board and keep the blend.\nIt lands here, with its CSS.")
                .font(Theme.text(14))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Space.margin)
    }

    private func entry(_ blend: SavedBlend) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.snug) {
            GradientRibbon(colours: blend.colours, height: 76, radius: 12)
                .padding(6)
                .softSurface(RoundedRectangle(cornerRadius: 18, style: .continuous),
                             depth: 7, pressed: true)

            HStack(spacing: Theme.Space.snug) {
                MoodLabel(blend.title)
                Spacer(minLength: 0)
                Button {
                    UIPasteboard.general.string = blend.css
                    Haptics.play(.snap)
                    withAnimation(Motion.quick) { copied = blend.id }
                } label: {
                    Label(copied == blend.id ? "Copied" : "CSS",
                          systemImage: copied == blend.id ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(OutlineButtonStyle(wide: false))

                Button {
                    withAnimation(Motion.tile) { library.remove(blend) }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(OutlineButtonStyle(wide: false))
                .accessibilityLabel("Delete this blend")
            }
        }
        .padding(Theme.Space.snug)
        .softSurface(RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous),
                     depth: 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(blend.title), \(blend.swatches.count) colours")
    }
}
