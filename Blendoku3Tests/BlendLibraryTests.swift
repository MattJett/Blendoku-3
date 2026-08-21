import XCTest
@testable import Blendoku3

/// A saved blend is the first thing in this app that cannot be regenerated —
/// progress can be earned again, a palette someone chose to keep cannot — so
/// the store gets tested like it matters.
@MainActor
final class BlendLibraryTests: XCTestCase {
    private var filename = ""

    override func setUp() {
        super.setUp()
        filename = "test-blends-\(UUID().uuidString).json"
    }

    override func tearDown() {
        if let url = try? FileManager.default.url(for: .applicationSupportDirectory,
                                                  in: .userDomainMask,
                                                  appropriateFor: nil, create: false) {
            try? FileManager.default.removeItem(at: url.appendingPathComponent(filename))
        }
        super.tearDown()
    }

    private var palette: [BlendColor] {
        [BlendColor(lightness: 0.3, chroma: 0.08, hue: 20),
         BlendColor(lightness: 0.6, chroma: 0.08, hue: 40)]
    }

    func testKeepingSurvivesAReload() {
        let library = BlendLibrary(filename: filename)
        library.keep(level: 7, colours: palette)
        // The write is asynchronous, so give it a beat before reading back.
        let written = expectation(description: "written")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { written.fulfill() }
        wait(for: [written], timeout: 2)

        let reloaded = BlendLibrary(filename: filename)
        XCTAssertEqual(reloaded.blends.count, 1)
        XCTAssertEqual(reloaded.blends.first?.level, 7)
        XCTAssertEqual(reloaded.blends.first?.swatches, palette.map(\.hexString))
        XCTAssertFalse(reloaded.isReadOnly)
    }

    func testKeepingTheSameLevelTwiceReplacesRatherThanStacks() {
        let library = BlendLibrary(filename: filename)
        library.keep(level: 12, colours: palette)
        library.keep(level: 12, colours: palette.reversed())
        XCTAssertEqual(library.blends.count, 1)
        XCTAssertEqual(library.blends.first?.swatches,
                       palette.reversed().map(\.hexString))
    }

    func testSameLevelInADifferentArcIsADifferentBlend() {
        let library = BlendLibrary(filename: filename)
        library.keep(level: 12, arc: 1, colours: palette)
        library.keep(level: 12, arc: 2, colours: palette)
        XCTAssertEqual(library.blends.count, 2)
        XCTAssertNotNil(library.saved(arc: 1, level: 12))
        XCTAssertNotNil(library.saved(arc: 2, level: 12))
    }

    func testNewestFirst() {
        let library = BlendLibrary(filename: filename)
        library.keep(level: 1, colours: palette)
        library.keep(level: 2, colours: palette)
        XCTAssertEqual(library.blends.map(\.level), [2, 1])
    }

    func testRemoving() {
        let library = BlendLibrary(filename: filename)
        let kept = library.keep(level: 3, colours: palette)
        library.remove(kept)
        XCTAssertTrue(library.isEmpty)
    }

    /// The whole point of the version number: a file written by a newer build
    /// still reads, but this build must not write over it.
    func testAFileFromANewerBuildIsNeverOverwritten() throws {
        let base = try FileManager.default.url(for: .applicationSupportDirectory,
                                               in: .userDomainMask,
                                               appropriateFor: nil, create: true)
        let url = base.appendingPathComponent(filename)
        let future = """
        {"version": \(BlendLibrary.currentVersion + 1), "blends": []}
        """
        try Data(future.utf8).write(to: url)

        let library = BlendLibrary(filename: filename)
        XCTAssertTrue(library.isReadOnly)
        library.keep(level: 5, colours: palette)

        let onDisk = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(onDisk, future, "a newer file was overwritten")
    }

    func testSavedBlendRebuildsItsColoursAndCSS() {
        let library = BlendLibrary(filename: filename)
        let kept = library.keep(level: 9, colours: palette)
        XCTAssertEqual(kept.colours.map(\.hexString), palette.map(\.hexString))
        XCTAssertTrue(kept.css.hasPrefix("linear-gradient(90deg, "))
        XCTAssertEqual(kept.title, "Arc 1 · Level 9")
    }
}
