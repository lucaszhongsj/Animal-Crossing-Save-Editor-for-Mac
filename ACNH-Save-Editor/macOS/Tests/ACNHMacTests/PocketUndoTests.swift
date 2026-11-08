import XCTest
import ACNHCore
@testable import ACNHMac

final class PocketUndoTests: XCTestCase {
    func testPocketUndoPreservesLaterNonPocketChanges() async throws {
        try await MainActor.run {
            let model = EditorModel()
            let apple = try PocketItem.make(id: 2213, quantity: 1, maxStack: 10)
            model.draft = SaveDraft(economy: [10], pockets: [.empty, .empty])
            model.change { $0.pockets[0] = apple }
            model.change { $0.pockets[1] = apple }
            model.change { $0.economy[0] = 20 }

            model.undoPocketEdit()
            XCTAssertEqual(model.draft?.pockets, [apple, .empty])
            XCTAssertEqual(model.draft?.economy, [20])

            model.undoPocketEdit()
            XCTAssertEqual(model.draft?.pockets, [.empty, .empty])
            XCTAssertFalse(model.canUndoPocketEdit)
            model.undo()
            XCTAssertEqual(model.draft?.economy, [10])
            XCTAssertEqual(model.draft?.pockets, [.empty, .empty])
        }
    }
}
