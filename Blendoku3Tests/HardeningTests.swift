import XCTest
@testable import Blendoku3

/// Save files are on disk, and anything on disk can be damaged, truncated or
/// edited. These write the bad files the app used to trust and check it now
/// shrugs them off instead of crashing or misbehaving.
final class ProgressHardeningTests: XCTestCase {
    private func store(with json: String) throws -> ProgressStore {
        let directory = Fixtures.scratchDirectory()
        try Data(json.utf8).write(to: directory.appendingPathComponent("progress.json"))
        return ProgressStore(directory: directory)
    }

    private func record(_ level: Int, moves: Int = 5, hints: Int = 0, perfect: Int = 5) -> String {
        """
        {"level": \(level), "moves": \(moves), "seconds": 12, "hintsUsed": \(hints), "perfectMoves": \(perfect)}
        """
    }

    /// The old loader trapped on this, on every launch, forever.
    func testALevelWrittenTwiceDoesNotCrashAndKeepsTheBetterRun() throws {
        let store = try store(with: """
        {"records": [\(record(3, moves: 40)), \(record(3, moves: 5)), \(record(3, moves: 30))],
         "lastPlayedLevel": 3}
        """)
        XCTAssertEqual(store.completedCount, 1)
        XCTAssertEqual(store.record(for: 3)?.moves, 5)
        XCTAssertEqual(store.record(for: 3)?.stars, 3)
    }

    /// Doubling a `perfectMoves` this size for the star count would overflow
    /// and take the app down.
    func testAnOverflowingRecordIsDropped() throws {
        let store = try store(with: """
        {"records": [\(record(1, perfect: Int.max)), \(record(2))], "lastPlayedLevel": 2}
        """)
        XCTAssertNil(store.record(for: 1))
        XCTAssertNotNil(store.record(for: 2))
        _ = store.totalStars
    }

    func testLevelsThatDoNotExistAreDropped() throws {
        let store = try store(with: """
        {"records": [\(record(0)), \(record(-4)), \(record(101)), \(record(7))], "lastPlayedLevel": 9000}
        """)
        XCTAssertEqual(store.completedCount, 1)
        XCTAssertEqual(store.lastPlayedLevel, DifficultyCurve.levelCount)
    }

    func testNegativeAndNonsenseCountsAreDropped() throws {
        let store = try store(with: """
        {"records": [\(record(1, moves: -3)), \(record(2, hints: -1)), \(record(3, perfect: 0))],
         "lastPlayedLevel": 1}
        """)
        XCTAssertEqual(store.completedCount, 0)
    }

    func testGarbageLeavesAFreshStart() throws {
        let store = try store(with: "\u{0}\u{1} definitely not json")
        XCTAssertEqual(store.completedCount, 0)
        XCTAssertEqual(store.furthestUnlocked, 1)
    }

    func testAnEnormousFileIsNotEvenRead() throws {
        let directory = Fixtures.scratchDirectory()
        let url = directory.appendingPathComponent("progress.json")
        try Data(count: Storage.maximumFileSize + 1).write(to: url)
        XCTAssertNil(Storage.read(url))
        XCTAssertEqual(ProgressStore(directory: directory).completedCount, 0)
    }

    func testProgressSurvivesAReload() {
        let directory = Fixtures.scratchDirectory()
        let store = ProgressStore(directory: directory)
        store.complete(level: 1, moves: 2, seconds: 5, hintsUsed: 0, perfectMoves: 2)
        store.complete(level: 2, moves: 9, seconds: 5, hintsUsed: 1, perfectMoves: 3)
        store.flush()
        let reloaded = ProgressStore(directory: directory)
        XCTAssertEqual(reloaded.completedCount, 2)
        XCTAssertEqual(reloaded.record(for: 2)?.stars, 1)
        XCTAssertEqual(reloaded.furthestUnlocked, 3)
    }
}

final class KeepsakeFormatTests: XCTestCase {
    private var palette: [BlendColor] {
        [BlendColor(lightness: 0.3, chroma: 0.08, hue: 20),
         BlendColor(lightness: 0.6, chroma: 0.08, hue: 40)]
    }

    /// Keepsakes saved before songs existed must still open, as blends.
    func testAVersionOneFileStillReads() throws {
        let directory = Fixtures.scratchDirectory()
        let v1 = """
        {"version": 1, "blends": [{"id": "6F9619FF-8B86-D011-B42D-00C04FC964FF", "arc": 1,
          "level": 12, "savedAt": 700000000, "swatches": ["#2E2A4A", "#E9C57F"]}]}
        """
        try Data(v1.utf8).write(to: directory.appendingPathComponent("blends.json"))
        let library = BlendLibrary(directory: directory)
        XCTAssertFalse(library.isReadOnly)
        XCTAssertEqual(library.blends.count, 1)
        XCTAssertEqual(library.blends[0].level, 12)
        XCTAssertFalse(library.blends[0].hasSong)
        XCTAssertNil(library.blends[0].song)
    }

    func testASongIsKeptWithItsBlend() {
        let directory = Fixtures.scratchDirectory()
        let session = GameSession(puzzle: Fixtures.allLevels[19])
        session.solveCompletely()
        let song = SongSchedule(puzzle: session.puzzle, order: session.placementOrder) {
            session.colour(at: $0)
        }

        let library = BlendLibrary(directory: directory)
        library.keep(level: 20, colours: palette,
                     melody: song.melody.map(\.colour),
                     spectrum: song.climb.map(\.colour),
                     warmth: 0.7)
        library.flush()

        let reloaded = BlendLibrary(directory: directory)
        let kept = try? XCTUnwrap(reloaded.saved(arc: 1, level: 20))
        XCTAssertEqual(kept?.hasSong, true)
        XCTAssertEqual(kept?.warmth, 0.7)
        let rebuilt = kept?.song
        XCTAssertEqual(rebuilt?.melody.count, song.melody.count)
        XCTAssertEqual(rebuilt?.climb.count, song.climb.count)
        XCTAssertEqual(rebuilt?.lastOnset ?? 0, song.lastOnset, accuracy: 1e-9)
        XCTAssertEqual(reloaded.songCount, 1)
    }

    func testWarmthIsClampedOnTheWayIn() {
        let library = BlendLibrary(directory: Fixtures.scratchDirectory())
        let kept = library.keep(level: 2, colours: palette, warmth: 7)
        XCTAssertEqual(kept.warmth, 1)
    }

    func testImplausibleKeepsakesAreDropped() throws {
        let directory = Fixtures.scratchDirectory()
        let json = """
        {"version": 2, "blends": [
          {"id": "6F9619FF-8B86-D011-B42D-00C04FC964F1", "arc": 1, "level": 400, "savedAt": 0, "swatches": ["#000000", "#FFFFFF"]},
          {"id": "6F9619FF-8B86-D011-B42D-00C04FC964F2", "arc": 1, "level": 4, "savedAt": 0, "swatches": ["#000000"]},
          {"id": "6F9619FF-8B86-D011-B42D-00C04FC964F3", "arc": 1, "level": 5, "savedAt": 0, "swatches": ["#000000", "#FFFFFF"], "warmth": 9},
          {"id": "6F9619FF-8B86-D011-B42D-00C04FC964F4", "arc": 1, "level": 6, "savedAt": 0, "swatches": ["#000000", "#FFFFFF"]}
        ]}
        """
        try Data(json.utf8).write(to: directory.appendingPathComponent("blends.json"))
        let library = BlendLibrary(directory: directory)
        XCTAssertEqual(library.blends.map(\.level), [6])
    }

    func testTheShelfHasACeiling() {
        let library = BlendLibrary(directory: Fixtures.scratchDirectory())
        for index in 0..<(BlendLibrary.capacity + 20) {
            library.keep(level: 1 + index % 100, arc: 1 + index / 100, colours: palette)
        }
        XCTAssertEqual(library.blends.count, BlendLibrary.capacity)
    }
}

/// The two grounds were renamed from paper and ink to light and shadow. The
/// choice is stored by name, so the old names have to keep working.
final class AppearanceTests: XCTestCase {
    private func defaults() -> UserDefaults {
        let name = "swatchword.tests.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: name)!
        suite.removePersistentDomain(forName: name)
        return suite
    }

    func testTheOldNamesStillMeanTheSameGround() {
        XCTAssertEqual(Appearance(stored: "paper"), .light)
        XCTAssertEqual(Appearance(stored: "ink"), .shadow)
        XCTAssertEqual(Appearance(stored: "system"), .system)
        XCTAssertEqual(Appearance(stored: "SHADOW"), .shadow)
        XCTAssertNil(Appearance(stored: "sepia"))
    }

    func testAPlayerWhoChoseInkStillGetsTheDarkGround() {
        let store = defaults()
        store.set("ink", forKey: "blendoku.appearance")
        let settings = GameSettings(defaults: store)
        XCTAssertEqual(settings.appearance, .shadow)
        XCTAssertEqual(settings.appearance.colorScheme, .dark)
        // Saved back under the new name.
        settings.persist()
        XCTAssertEqual(store.string(forKey: "blendoku.appearance"), "shadow")
    }

    func testTheNewSwitchesDefaultOnAndPersist() {
        let store = defaults()
        let settings = GameSettings(defaults: store)
        XCTAssertTrue(settings.replayEnabled)
        XCTAssertTrue(settings.beatEnabled)
        XCTAssertTrue(settings.showGridLabels, "positions were always announced before the switch worked")
        settings.replayEnabled = false
        settings.beatEnabled = false
        settings.persist()
        let reloaded = GameSettings(defaults: store)
        XCTAssertFalse(reloaded.replayEnabled)
        XCTAssertFalse(reloaded.beatEnabled)
    }

    func testTheGroundsAreOfferedInOrder() {
        XCTAssertEqual(Appearance.allCases.map(\.title), ["Light", "Shadow", "Auto"])
    }
}

@MainActor
final class NavigationTests: XCTestCase {
    func testTheGameOpensOnItsTitlePage() {
        let router = AppRouter()
        XCTAssertEqual(router.current, .title)
        XCTAssertFalse(router.canGoBack)
    }

    func testBeginningLeavesTheTitlePageForGood() {
        let router = AppRouter()
        router.begin()
        XCTAssertEqual(router.stack, [.home])
        router.pop()
        XCTAssertEqual(router.current, .home, "Back must never return to the title page")
        router.push(.title)
        XCTAssertEqual(router.current, .home)
        router.popToRoot()
        XCTAssertEqual(router.stack, [.home])
    }

    func testASolvedBoardCanGoStraightToTheArcs() {
        let router = AppRouter(stack: [.home, .chromarcs, .levels, .game(40)])
        router.replaceTop(with: .game(41))
        XCTAssertEqual(router.stack.count, 4, "moving between levels must not grow the stack")
        router.showArcs()
        XCTAssertEqual(router.stack, [.home, .chromarcs])
        router.pop()
        XCTAssertEqual(router.current, .home)
    }

    func testLeavingABoardForTheLevelsClimbsTheHierarchy() {
        let router = AppRouter(stack: [.home, .game(12)])
        router.showLevels()
        XCTAssertEqual(router.stack, [.home, .chromarcs, .levels])
    }

    func testPushingTheSameScreenTwiceIsIgnored() {
        let router = AppRouter(stack: [.home])
        router.push(.settings)
        router.push(.settings)
        XCTAssertEqual(router.stack, [.home, .settings])
    }
}

final class ArcStandingTests: XCTestCase {
    private let arcs: [Chromarc] = [
        Chromarc(number: 1, title: "One", span: 0...1, isPlayable: true),
        Chromarc(number: 2, title: "Two", span: 0...1, isPlayable: true),
        Chromarc(number: 3, title: "Three", span: 0...1, isPlayable: false),
    ]

    func testAtTheStartTheFirstArcIsCurrentAndTheRestLocked() {
        let standings = Chromarc.standings(arcs) { _ in 0 }
        XCTAssertEqual(standings, [1: .current, 2: .locked, 3: .locked])
    }

    func testPartwayThroughStillTheFirst() {
        let standings = Chromarc.standings(arcs) { $0.number == 1 ? 62 : 0 }
        XCTAssertEqual(standings[1], .current)
    }

    func testFinishingAnArcStampsItDoneAndMovesOn() {
        let standings = Chromarc.standings(arcs) { $0.number == 1 ? 100 : 3 }
        XCTAssertEqual(standings, [1: .done, 2: .current, 3: .locked])
    }

    func testAnUnbuiltArcIsLockedEvenWhenItIsNext() {
        let standings = Chromarc.standings(arcs) { $0.number <= 2 ? 100 : 0 }
        XCTAssertEqual(standings, [1: .done, 2: .done, 3: .locked])
    }

    func testTheRealArcsToday() {
        let standings = Chromarc.standings { _ in 0 }
        XCTAssertEqual(standings[1], .current)
        XCTAssertEqual(standings[2], .locked)
    }
}
