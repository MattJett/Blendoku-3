import Foundation
import Observation

/// A tiny navigation stack. Custom rather than `NavigationStack` so screens can
/// cross-fade and slide together instead of pushing opaque sheets over the
/// animated backdrop.
@MainActor
@Observable
final class AppRouter {
    enum Screen: Hashable {
        case home
        case levels
        case game(Int)
        case howToPlay
        case settings
        case collection
        case chromarcs
        case arcComplete(Int)
    }

    private(set) var stack: [Screen] = [.home]
    /// Which way the next transition should travel.
    private(set) var isMovingForward = true
    /// Colours the aurora behind everything; each screen sets its own.
    var backdropPalette: [BlendColor] = []

    var current: Screen { stack.last ?? .home }
    var canGoBack: Bool { stack.count > 1 }

    func push(_ screen: Screen) {
        guard screen != current else { return }
        isMovingForward = true
        stack.append(screen)
    }

    func pop() {
        guard stack.count > 1 else { return }
        isMovingForward = false
        stack.removeLast()
    }

    func popToRoot() {
        guard stack.count > 1 else { return }
        isMovingForward = false
        stack = [.home]
    }

    /// Used when moving between levels, so the stack does not grow forever.
    func replaceTop(with screen: Screen) {
        isMovingForward = true
        if stack.isEmpty { stack = [screen] } else { stack[stack.count - 1] = screen }
    }
}
