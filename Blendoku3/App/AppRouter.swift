import Foundation
import Observation

/// A tiny navigation stack. Custom rather than `NavigationStack` so screens can
/// cross-fade and slide together instead of pushing opaque sheets over the
/// animated backdrop.
@MainActor
@Observable
final class AppRouter {
    enum Screen: Hashable {
        /// The title page. Only ever the first thing on screen after launch,
        /// and never gone back to: once the player is in, Home is the root.
        case title
        case home
        case levels
        case game(Int)
        case howToPlay
        case settings
        case keepsakes
        case chromarcs
        case arcComplete(Int)
    }

    private(set) var stack: [Screen]
    /// Which way the next transition should travel.
    private(set) var isMovingForward = true
    /// Colours the aurora behind everything; each screen sets its own.
    var backdropPalette: [BlendColor] = []

    init(stack: [Screen] = [.title]) {
        self.stack = stack.isEmpty ? [.title] : stack
    }

    var current: Screen { stack.last ?? .home }
    var canGoBack: Bool { stack.count > 1 }

    /// Leaves the title page for good.
    func begin() {
        isMovingForward = true
        stack = [.home]
    }

    func push(_ screen: Screen) {
        guard screen != current, screen != .title else { return }
        isMovingForward = true
        stack.append(screen)
    }

    func pop() {
        guard stack.count > 1 else { return }
        isMovingForward = false
        stack.removeLast()
    }

    func popToRoot() {
        isMovingForward = false
        stack = [.home]
    }

    /// Straight to the arc chooser, with Home behind it — from a solved
    /// board, a finished arc, anywhere the way back should not run through
    /// the level that was just played.
    func showArcs() {
        isMovingForward = false
        stack = [.home, .chromarcs]
    }

    /// The level list, with the arc it belongs to and Home behind it, so
    /// Back climbs the hierarchy rather than retracing whatever route led in.
    func showLevels() {
        isMovingForward = false
        stack = [.home, .chromarcs, .levels]
    }

    /// Used when moving between levels, so the stack does not grow forever.
    func replaceTop(with screen: Screen) {
        guard screen != .title else { return }
        isMovingForward = true
        if stack.isEmpty { stack = [screen] } else { stack[stack.count - 1] = screen }
    }
}
