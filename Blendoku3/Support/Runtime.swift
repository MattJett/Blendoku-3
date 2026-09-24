import Foundation

/// Facts about how this process was launched.
enum Runtime {
    /// XCTest sets this in the environment of any app it injects unit tests
    /// into. The app still launches as their host, so it has to know to keep
    /// quiet.
    static let isUnitTesting =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    /// The UI tests launch the app with this argument. It also points every
    /// store at a scratch directory, so a test run can neither read nor
    /// damage anyone's real progress.
    static let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")

    /// Tests are silent: no tones, no vibration. A suite that buzzes the
    /// desk every time it runs is a suite people stop running.
    static var isSilent: Bool { isUnitTesting || isUITesting }

    /// Ambient motion — the drifting backdrop, the breathing prompt — never
    /// finishes, and UI tests wait for the screen to settle before every tap.
    /// Under test it is held still, the same as for anyone who has asked the
    /// system to reduce motion.
    static var holdsStill: Bool { isUITesting }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}

/// Where the game keeps what it writes.
enum Storage {
    /// Application Support, or — under UI tests — an empty scratch folder
    /// made fresh for the run.
    static let directory: URL = {
        let manager = FileManager.default
        if Runtime.isUITesting {
            let scratch = manager.temporaryDirectory
                .appendingPathComponent("swatchword-uitests", isDirectory: true)
            try? manager.removeItem(at: scratch)
            try? manager.createDirectory(at: scratch, withIntermediateDirectories: true)
            return scratch
        }
        return (try? manager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                 appropriateFor: nil, create: true))
            ?? manager.temporaryDirectory
    }()

    /// Preferences, with the same separation: UI tests get a volatile suite
    /// wiped at launch, so a test that flips a switch never flips yours.
    static let defaults: UserDefaults = {
        guard Runtime.isUITesting, let suite = UserDefaults(suiteName: "swatchword.uitests") else {
            return .standard
        }
        suite.removePersistentDomain(forName: "swatchword.uitests")
        return suite
    }()

    /// Nothing the game writes is anywhere near this size. A file that is
    /// has been tampered with or corrupted, and reading it into memory to find
    /// that out is the one thing worth avoiding.
    static let maximumFileSize = 2 * 1024 * 1024

    /// Reads a save file, refusing anything implausibly large.
    static func read(_ url: URL) -> Data? {
        guard let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize,
              size <= maximumFileSize else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Writes atomically — a crash mid-write leaves the previous file, never
    /// half of a new one — and under the standard protection class, so the
    /// file is encrypted at rest until the phone is first unlocked.
    static func write(_ data: Data, to url: URL) {
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
