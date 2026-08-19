import SwiftUI

/// Screens slide a short distance rather than the full width — enough to read
/// as a push without the content ever leaving the glass.
struct ScreenSlide: ViewModifier {
    var offset: CGFloat
    var opacity: Double
    var scale: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .scaleEffect(scale)
            .offset(x: offset)
    }
}

extension AnyTransition {
    static func screen(forward: Bool) -> AnyTransition {
        let identity = ScreenSlide(offset: 0, opacity: 1, scale: 1)
        return .asymmetric(
            insertion: .modifier(
                active: ScreenSlide(offset: forward ? 44 : -44, opacity: 0, scale: 0.985),
                identity: identity),
            removal: .modifier(
                active: ScreenSlide(offset: forward ? -34 : 34, opacity: 0, scale: 0.985),
                identity: identity))
    }

    static var popIn: AnyTransition {
        .scale(scale: 0.86).combined(with: .opacity)
    }
}

/// Fades and lifts a view in, staggered by its position in a list.
struct StaggeredAppear: ViewModifier {
    var index: Int
    var perItem: Double = 0.022
    var travel: CGFloat = 14

    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : travel)
            .onAppear {
                withAnimation(.spring(response: 0.46, dampingFraction: 0.82)
                    .delay(Double(index) * perItem)) {
                    shown = true
                }
            }
    }
}

extension View {
    func staggeredAppear(index: Int, perItem: Double = 0.022, travel: CGFloat = 14) -> some View {
        modifier(StaggeredAppear(index: index, perItem: perItem, travel: travel))
    }
}
