import XCTest
@testable import ACNHCore

final class BridgeTypeTests: XCTestCase {
    func testNHSEModelsAndStyleChangesPreserveEveryGeometry() throws {
        let models: [(BridgeStyle, [UInt16])] = [
            (.stone, [0,1,2,3,4,5]), (.suspension, [7,6,8,9,10,11]),
            (.zen, [19,12,20,21,22,23]), (.log, [14,13,15,16,17,18]),
            (.redZen, [32,24,33,34,35,36]), (.iron, [39,25,40,41,42,43]),
            (.reserved, [26,27,28,29,30,31]), (.wooden, [44,37,45,46,47,48]),
            (.brick, [49,38,52,53,54,55])
        ]
        for (style, ids) in models {
            for (geometry, id) in ids.enumerated() {
                let type = try XCTUnwrap(BridgeType(id))
                XCTAssertEqual(type.style, style)
                XCTAssertEqual(type.isDiagonal, geometry >= 3)
                XCTAssertEqual(type.span, [3,4,5,2.5,3,3.5][geometry])
                for (newStyle, newIDs) in models {
                    let changed = type.replacingStyle(with: newStyle)
                    XCTAssertEqual(changed.id, newIDs[geometry])
                    XCTAssertEqual(changed.span, type.span)
                    XCTAssertEqual(changed.isDiagonal, type.isDiagonal)
                }
            }
        }
        for id: UInt16 in [50,51,56,65535] { XCTAssertNil(BridgeType(id)) }
        XCTAssertEqual(BridgeStyle.allCases.map(\.rawValue), [0,1,2,4,5,6,7,10,11])
    }

    func testEveryBridgeTypeWritesOnlyModelAndMaterial() throws {
        var before = IslandSnapshot.preview().main
        let index = 9, offset = IslandLayout.buildings + index * IslandLayout.buildingSize
        // Distinct sentinels for flags, material, padding, unique ID, and unused bytes.
        before.replaceSubrange((offset + 7)..<(offset + 20), with: Data((0xA0...0xAC).map(UInt8.init)))
        for id in UInt16(0)...55 {
            guard let type = BridgeType(id) else { continue }
            var main = before, edits = IslandEdits()
            edits.bridgeTypes[index] = id
            XCTAssertFalse(edits.isEmpty)
            XCTAssertEqual(IslandSnapshot(main: main).building(index, edits: edits).subtype, id)
            try edits.applying(to: &main)
            XCTAssertEqual(main.u16(offset + 8), id)
            XCTAssertEqual(main[offset + 10], type.style.rawValue)
            main.replaceSubrange((offset + 8)..<(offset + 11), with: before[(offset + 8)..<(offset + 11)])
            XCTAssertEqual(main, before)
        }
    }

    func testInvalidTypesAndNonBridgeTargetsAreRejected() {
        for (index, id): (Int, UInt16) in [(-1,0),(46,0),(0,0),(45,0),(9,50),(9,51),(9,65535)] {
            var main = IslandSnapshot.preview().main, edits = IslandEdits()
            edits.bridgeTypes[index] = id
            XCTAssertThrowsError(try edits.applying(to: &main))
        }
    }
}
