import Foundation

/// A cell coordinate on the puzzle board. `y` grows downwards.
struct GridPoint: Hashable, Sendable, Comparable, Codable {
    var x: Int
    var y: Int

    init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }

    static func < (lhs: GridPoint, rhs: GridPoint) -> Bool {
        lhs.y == rhs.y ? lhs.x < rhs.x : lhs.y < rhs.y
    }

    func offset(dx: Int, dy: Int) -> GridPoint { GridPoint(x + dx, y + dy) }

    /// Chebyshev distance — used to keep independent shapes from touching.
    func chebyshevDistance(to other: GridPoint) -> Int {
        max(abs(x - other.x), abs(y - other.y))
    }
}

/// Integer bounding box over a set of grid points.
struct GridBounds: Hashable, Sendable {
    var minX: Int
    var minY: Int
    var maxX: Int
    var maxY: Int

    var width: Int { maxX - minX + 1 }
    var height: Int { maxY - minY + 1 }

    init?(points: some Collection<GridPoint>) {
        guard let first = points.first else { return nil }
        minX = first.x; maxX = first.x
        minY = first.y; maxY = first.y
        for point in points {
            minX = min(minX, point.x); maxX = max(maxX, point.x)
            minY = min(minY, point.y); maxY = max(maxY, point.y)
        }
    }
}
