import XCTest

/// Walks the game the way a player does — title, menus, a board, the pause
/// menu, a solve, the song, a keepsake — and fails if any screen does not turn
/// up or the app dies on the way.
///
/// Silent by construction. Every launch passes `-uiTesting`, which the app
/// reads as: no tones, no vibration, no ambient motion, and every store
/// pointed at a scratch folder wiped at launch. A run cannot make a sound,
/// cannot buzz the desk, and cannot touch anyone's real progress.
final class SmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        // The flag carries a value so the argument parser can never mistake
        // the next `-key` for it.
        app.launchArguments = ["-uiTesting", "YES"] + arguments
        app.launch()
        return app
    }

    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func expect(_ id: String, in app: XCUIApplication, timeout: TimeInterval = 10,
                        file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element(id, in: app).waitForExistence(timeout: timeout),
                      "\(id) never appeared", file: file, line: line)
    }

    private func tap(_ id: String, in app: XCUIApplication, timeout: TimeInterval = 10,
                     file: StaticString = #filePath, line: UInt = #line) {
        expect(id, in: app, timeout: timeout, file: file, line: line)
        element(id, in: app).tap()
    }

    // MARK: - Flows

    func testTitlePageLeadsToHome() {
        let app = launch()
        tap("title.begin", in: app)
        expect("home.play", in: app)
        expect("home.arcs", in: app)
        expect("home.keepsakes", in: app)
        expect("home.settings", in: app)
    }

    func testEveryMenuScreenOpensAndComesBack() {
        let app = launch(["-uiPreviewScreen", "home"])

        tap("home.arcs", in: app)
        expect("arcs.1", in: app)
        // A locked arc answers a press with a refusal, not a crash.
        tap("arcs.2", in: app)
        tap("screen.back", in: app)

        tap("home.keepsakes", in: app)
        expect("screen.back", in: app)
        tap("screen.back", in: app)

        tap("home.settings", in: app)
        tap("settings.ground.shadow", in: app)
        tap("settings.ground.light", in: app)
        tap("settings.replay", in: app)
        tap("settings.replay", in: app)
        tap("screen.back", in: app)

        expect("home.play", in: app)
    }

    func testPausingResumingAndLeavingABoard() {
        let app = launch(["-uiPreviewScreen", "home"])

        tap("home.play", in: app)
        tap("game.pause", in: app)
        tap("pause.resume", in: app)
        tap("game.hint", in: app)

        tap("game.pause", in: app)
        tap("pause.home", in: app)
        expect("home.play", in: app)

        // The hint was a move, so the board was kept and Play resumes it.
        tap("home.play", in: app)
        tap("game.pause", in: app)
        tap("pause.levels", in: app)
        expect("level.1", in: app)
    }

    func testASolvedBoardPlaysItsSongThenOffersTheWayOut() {
        // The biggest board, because its song is the longest: about ten
        // seconds, which leaves the skip in place long enough to press even
        // while the test runner waits for the board's lights to settle.
        let app = launch(["-uiPreviewLevel", "100", "-uiPreviewSolved", "1"])

        tap("replay.skip", in: app, timeout: 15)
        tap("victory.keep", in: app, timeout: 20)
        tap("victory.arcs", in: app)
        expect("arcs.1", in: app)

        tap("screen.back", in: app)
        tap("home.keepsakes", in: app)
        // The keepsake came with its song, so it can be played back.
        let play = app.buttons["Play the song"]
        XCTAssertTrue(play.waitForExistence(timeout: 10), "the kept board has no song")
        play.tap()
    }

    func testTheFirstBoardsWalkthroughCanBeSkipped() {
        let app = launch(["-uiPreviewLevel", "1"])
        tap("coach.skip", in: app)
        let gone = expectation(for: NSPredicate(format: "exists == false"),
                               evaluatedWith: element("coach.skip", in: app))
        wait(for: [gone], timeout: 5)
        expect("game.pause", in: app)
    }
}
