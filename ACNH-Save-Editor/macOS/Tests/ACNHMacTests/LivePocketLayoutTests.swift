import XCTest
import ACNHCore
@testable import ACNHMac

final class LivePocketLayoutTests: XCTestCase {
    func testInventoryMatchesAcrossDifferentBookkeepingButChecksBothCapacities() throws {
        var first = Data(repeating: 0, count: LivePocketLayout.span)
        first.put32(20, at: LivePocketLayout.upper + LivePocketLayout.block)
        first.put32(10, at: LivePocketLayout.block)
        let layout = try LivePocketLayout(first)
        XCTAssertEqual(layout.offsets.count, 30)
        XCTAssertEqual(layout.offsets[0], LivePocketLayout.upper)
        XCTAssertEqual(layout.offsets[20], 0)
        var second = first
        second[LivePocketLayout.block + 4] = 1
        XCTAssertTrue(LivePocketLayout.sameInventory(first, second))
        second.put32(20, at: LivePocketLayout.block)
        XCTAssertFalse(LivePocketLayout.sameInventory(first, second))
    }

    func testHeapRangeSupportsTheRebuiltNxnativeAddressSpace() {
        let log = "fork patches: none\n[dm] guest AS 0x79de400000 +0x10f0000000  heap 0x79ee400000 alias 0x7ace400000"
        XCTAssertEqual(LivePocketConnection.heapRange(in: log), 0x79ee400000..<0x8ace400000)
    }

    func testFindsTheLivePairOnBothRebuilds() {
        XCTAssertEqual(
            LivePocketLayout.uniqueLivePair(in: [0x70e20bb100, 0x70547bf200, 0x70e20466a0]),
            [0x70e20466a0, 0x70e20bb100]
        )
        XCTAssertEqual(
            LivePocketLayout.uniqueLivePair(in: [0x7a12bbf200, 0x7aa04466a0, 0x7aa04bb100]),
            [0x7aa04466a0, 0x7aa04bb100]
        )
    }

    func testAllowsAnUnsavedStackChangeWithOtherMatchingItems() throws {
        var saved = Data(repeating: 0, count: LivePocketLayout.span)
        saved.put32(20, at: LivePocketLayout.upper + LivePocketLayout.block)
        let layout = try LivePocketLayout(saved)
        for (slot, offset) in layout.offsets.enumerated() {
            saved.replaceSubrange(offset..<(offset + 8), with: PocketItem.empty.raw)
            if slot < 4 { saved.put16(UInt16(2213 + slot), at: offset) }
        }
        var live = saved
        live.put16(3, at: layout.offsets[0] + 4)
        XCTAssertTrue(layout.resemblesSave(live, baseline: saved))
        live.put16(3, at: layout.offsets[1] + 4)
        XCTAssertFalse(layout.resemblesSave(live, baseline: saved))
    }

    func testRejectsMissingOrAmbiguousPairs() {
        XCTAssertNil(LivePocketLayout.uniqueLivePair(in: [0x100, 0x200]))
        XCTAssertNil(LivePocketLayout.uniqueLivePair(in: [0x100, 0x74b60, 0xe95c0]))
    }
}
