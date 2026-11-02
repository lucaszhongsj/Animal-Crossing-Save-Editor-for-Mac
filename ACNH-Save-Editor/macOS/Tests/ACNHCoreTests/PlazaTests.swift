import XCTest
@testable import ACNHCore

final class PlazaTests: XCTestCase {
    func testNHSELayoutAndUInt32Read() {
        XCTAssertEqual(IslandLayout.plaza, 0x32FB40)
        var main = IslandSnapshot.preview().main
        main.put32(0x12345678, at: IslandLayout.plaza)
        main.put32(0x87654321, at: IslandLayout.plaza + 4)
        let world = IslandSnapshot(main: main)
        XCTAssertEqual(world.plaza(), PlazaPosition(x: 0x12345678, y: 0x87654321))
        var edits = IslandEdits()
        edits.plaza = PlazaPosition(x: 101, y: 93)
        XCTAssertFalse(edits.isEmpty)
        XCTAssertEqual(world.plaza(edits: edits), edits.plaza)
        edits.plaza = nil
        XCTAssertTrue(edits.isEmpty)
    }

    func testMoveOnlyWritesPlazaCoordinatesAndPreservesBuildingsAndAcres() throws {
        let before = IslandSnapshot.preview().main
        for position in [PlazaPosition(x: 101, y: 93), PlazaPosition(x: 0, y: 0), PlazaPosition(x: 1024, y: 1024)] {
            var main = before, edits = IslandEdits()
            edits.plaza = position
            try edits.applying(to: &main)
            XCTAssertEqual(IslandSnapshot(main: main).plaza(), position)
            main.replaceSubrange(IslandLayout.plaza..<(IslandLayout.plaza + 8),
                                 with: before[IslandLayout.plaza..<(IslandLayout.plaza + 8)])
            XCTAssertEqual(main, before)
        }
        for position in [PlazaPosition(x: 1025, y: 0), PlazaPosition(x: 0, y: 1025), PlazaPosition(x: .max, y: .max)] {
            var main = before, edits = IslandEdits()
            edits.plaza = position
            XCTAssertThrowsError(try edits.applying(to: &main))
            XCTAssertEqual(main, before)
        }
    }

    func testPlazaGuideUsesUpperLeftAnchorAndZoomForSelection() {
        let position = PlazaPosition(x: 101, y: 93)
        for zoom in [0.5, 3, 8, 14] {
            let bounds = MapCoordinates.plazaBounds(position, zoom: zoom)
            XCTAssertEqual(bounds.minX, 50.5 * zoom)
            XCTAssertEqual(bounds.minY, 46.5 * zoom)
            XCTAssertEqual(bounds.width, 12 * zoom)
            XCTAssertEqual(bounds.height, 10 * zoom)
            XCTAssertTrue(MapCoordinates.plazaAt(x: bounds.minX + 0.1, y: bounds.minY + 0.1, zoom: zoom, position: position))
            XCTAssertFalse(MapCoordinates.plazaAt(x: bounds.minX - 0.1, y: bounds.midY, zoom: zoom, position: position))
            XCTAssertFalse(MapCoordinates.plazaAt(x: bounds.maxX + 0.1, y: bounds.midY, zoom: zoom, position: position))
            XCTAssertFalse(MapCoordinates.plazaAt(x: .nan, y: bounds.midY, zoom: zoom, position: position))
            XCTAssertFalse(MapCoordinates.plazaAt(x: -1, y: -1, zoom: zoom, position: position))
        }
        XCTAssertFalse(MapCoordinates.plazaAt(x: 1, y: 1, zoom: 0, position: position))
        XCTAssertFalse(MapCoordinates.plazaAt(x: 200, y: 200, zoom: 3, position: PlazaPosition(x: 1024, y: 1024)))
    }
}
