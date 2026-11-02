import XCTest
@testable import ACNHCore

final class IslandEditorTests: XCTestCase {
    var root: URL!
    var folder: URL { root.appendingPathComponent("Island") }
    static let files: [String: Data] = {
        var result = SaveEngineTests.fixtureFiles
        var main = IslandSnapshot.preview().main
        main.replaceSubrange(0..<16, with: result["mainHeader.dat"]!.prefix(16))
        SaveCodec.writeMoney(548_000, to: &main, at: SaveLayout.loan)
        main[0x120 + 0x1267A] = 0x80
        main[0x481D20] = 0xBD // unrelated villager house sentinel
        main[0x900000] = 0xF1
        SaveLayout.rehash(&main, regions: SaveLayout.mainRegions)
        result["main.dat"] = try! SaveCodec.crypt(main, header: result["mainHeader.dat"]!)
        return result
    }()
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("IslandTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("Villager0"), withIntermediateDirectories: true)
        for (path, data) in Self.files { try data.write(to: folder.appendingPathComponent(path)) }
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    func testNHSECoordinateLayoutAndGoldenTerrainRecord() throws {
        XCTAssertEqual(IslandLayout.terrain, 0x110 + 0x22F3F0 + 0xDB600)
        XCTAssertEqual(IslandLayout.buildings, 0x110 + 0x22F3F0 + 0x100200)
        XCTAssertEqual(IslandLayout.acres, 0x110 + 0x22F3F0 + 0x1005AC)
        XCTAssertEqual(try IslandLayout.terrainIndex(x: 1, y: 0), 96)
        XCTAssertEqual(try IslandLayout.fieldIndex(x: 1, y: 0, layer: 1), 55_296 + 192)
        let bytes = Data([0x15,0,2,0,3,0,0x94,0,1,0,2,0,1,0])
        let tile = TerrainTile(raw: bytes)
        XCTAssertEqual(tile.ground, 0x15); XCTAssertEqual(tile.path, 0x94)
        XCTAssertEqual(tile.elevation, 1); XCTAssertEqual(tile.raw, bytes)
        try tile.validate()
        if let output = ProcessInfo.processInfo.environment["ACNH_ISLAND_FIXTURE_OUTPUT"] {
            try FileManager.default.copyItem(at: folder, to: URL(fileURLWithPath: output))
        }
    }
    func testTerrainPathsAndBuildingExportPreserveUnrelatedData() throws {
        let session = try SaveSession(folder: folder), world = IslandSnapshot(main: session.main)
        var draft = session.initial
        let index = try IslandLayout.terrainIndex(x: 30, y: 35)
        var tile = world.terrain(index); tile.ground = 0x15; tile.elevation = 2; tile.path = 0x94; tile.pathAngle = 3
        draft.island.terrain[index] = tile
        draft.island.buildings[0] = BuildingPosition(x: 41, y: 61, angle: 2)
        let destination = root.appendingPathComponent("Edited")
        try session.export(draft, to: destination)
        let reopened = try SaveSession(folder: destination), changed = IslandSnapshot(main: reopened.main)
        XCTAssertEqual(changed.terrain(index), tile)
        XCTAssertEqual(changed.building(0).position, BuildingPosition(x: 41, y: 61, angle: 2))
        XCTAssertEqual(changed.building(0).kind, 1)
        XCTAssertEqual(reopened.personal, session.personal)
        assertOnlyChanges(session.main, reopened.main, ranges: [
            (IslandLayout.terrain + index * 14)..<(IslandLayout.terrain + index * 14 + 14),
            (IslandLayout.buildings + 2)..<(IslandLayout.buildings + 7)
        ])
        try session.ensureUnchanged()
    }
    func testBridgeStyleAndPositionExportTogetherWithoutChangingOtherRecords() throws {
        let session = try SaveSession(folder: folder)
        let index = 9, offset = IslandLayout.buildings + index * IslandLayout.buildingSize
        var draft = session.initial
        draft.island.bridgeTypes[index] = 52 // Brick, five-tile straight span; material 11.
        draft.island.buildings[index] = BuildingPosition(x: 151, y: 149, angle: 1)
        let destination = root.appendingPathComponent("BridgeStyle")
        try session.export(draft, to: destination)
        let reopened = try SaveSession(folder: destination)
        let bridge = IslandSnapshot(main: reopened.main).building(index)
        XCTAssertEqual(bridge.subtype, 52)
        XCTAssertEqual(bridge.position, draft.island.buildings[index])
        XCTAssertEqual(reopened.main[offset + 10], 11)
        XCTAssertEqual(BuildingFootprint.forBuilding(bridge)?.width, 7)
        XCTAssertEqual(reopened.personal, session.personal)
        assertOnlyChanges(session.main, reopened.main, ranges: [(offset + 2)..<(offset + 7), (offset + 8)..<(offset + 11)])
        try session.ensureUnchanged()
    }
    func testPlazaExportReopensWithoutMovingResidentServices() throws {
        let session = try SaveSession(folder: folder)
        var draft = session.initial
        draft.island.plaza = PlazaPosition(x: 111, y: 97)
        let destination = root.appendingPathComponent("Plaza")
        try session.export(draft, to: destination)
        let reopened = try SaveSession(folder: destination)
        XCTAssertEqual(IslandSnapshot(main: reopened.main).plaza(), draft.island.plaza)
        XCTAssertEqual(reopened.personal, session.personal)
        assertOnlyChanges(session.main, reopened.main, ranges: [IslandLayout.plaza..<(IslandLayout.plaza + 8)])
        try session.ensureUnchanged()
    }
    func testVillagerRoundTripPreservesHouseMemoriesAndMoveBits() throws {
        let session = try SaveSession(folder: folder), world = IslandSnapshot(main: session.main)
        var draft = session.initial, villager = world.villager(0)
        villager.variant = 1; villager.personality = 2; villager.catchphrase = "Hello 🌴"; villager.movingOut = true; villager.friendship[0] = 200
        draft.island.villagers[0] = villager
        let destination = root.appendingPathComponent("Edited")
        try session.export(draft, to: destination)
        let reopened = try SaveSession(folder: destination), changed = IslandSnapshot(main: reopened.main)
        XCTAssertEqual(changed.villager(0), villager)
        XCTAssertEqual(changed.memoryName(villager: 0, memory: 0), "Player")
        XCTAssertEqual(reopened.main[0x120 + 0x1267A], 0x82)
        XCTAssertEqual(reopened.main[0x481D20], 0xBD)
        let offset = 0x120
        assertOnlyChanges(session.main, reopened.main, ranges: [offset..<(offset + 3), (offset + 0x10794)..<(offset + 0x107C4), (offset + 0x1267A)..<(offset + 0x1267B), (offset + 0x46)..<(offset + 0x47)])
    }
    func testOutdoorItemFootprintsAndExtensionRemovalOnBothLayers() throws {
        let world = IslandSnapshot.preview()
        let item = try PocketItem.make(id: 0x9C9, quantity: 10, maxStack: 30)
        for layer in 0...1 {
            let rootIndex = try IslandLayout.fieldIndex(x: 100, y: 80, layer: layer)
            let edits = try world.dropping(item, at: rootIndex, edits: .init())
            XCTAssertEqual(edits.fieldItems.count, 4)
            XCTAssertEqual(world.fieldItem(rootIndex, edits: edits).id, 0x9C9)
            XCTAssertEqual(world.fieldItem(rootIndex, edits: edits).raw[2], 0x20)
            let extensionIndex = try IslandLayout.fieldIndex(x: 101, y: 81, layer: layer)
            XCTAssertEqual(world.fieldItem(extensionIndex, edits: edits).id, 0xFFFD)
            XCTAssertEqual(try world.rootIndex(for: extensionIndex, edits: edits), rootIndex)
            let cleared = try world.removingItem(at: extensionIndex, edits: edits)
            XCTAssertTrue(cleared.fieldItems.values.allSatisfy(\.isEmpty))
            let untouchedOtherLayer = try IslandLayout.fieldIndex(x: 100, y: 80, layer: 1 - layer)
            XCTAssertTrue(world.fieldItem(untouchedOtherLayer, edits: edits).isEmpty)
        }
    }
    func testOutdoorActivationFlagsUseRowMajorBitPositions() throws {
        var main = IslandSnapshot.preview().main
        let base = IslandLayout.field + IslandLayout.fieldLayerSize * 2
        main.replaceSubrange(base..<(base + 0x3600), with: Data(repeating: 0xFF, count: 0x3600))
        let world = IslandSnapshot(main: main)
        let index = try IslandLayout.fieldIndex(x: 101, y: 41, layer: 1)
        let item = try PocketItem.make(id: 0x9C9, quantity: 1, maxStack: 30)
        let edits = try world.dropping(item, at: index, edits: .init())
        try edits.applying(to: &main)
        var expected = Data(repeating: 0xFF, count: 0x3600)
        for x in 101...102 { for y in 41...42 { let bit = y * 288 + x; expected[0x1B00 + bit / 8] &= ~(1 << (bit % 8)) } }
        XCTAssertEqual(main.subdata(in: base..<(base + 0x3600)), expected)
    }
    func testMapCornersAndBothItemLayersSurviveExportAndRemoval() throws {
        let session = try SaveSession(folder: folder), world = IslandSnapshot(main: session.main)
        var draft = session.initial
        var expectedRanges: [Range<Int>] = []
        let corners = [(0, 0), (111, 0), (0, 95), (111, 95)]
        for (x, y) in corners {
            let index = try IslandLayout.terrainIndex(x: x, y: y)
            var tile = world.terrain(index)
            tile.ground = 0x15; tile.angle = 3; tile.elevation = 2
            tile.path = 0x94; tile.pathAngle = 2
            draft.island.terrain[index] = tile
            let offset = IslandLayout.terrain + index * 14
            expectedRanges.append(offset..<(offset + 14))
        }
        let item = try PocketItem.make(id: 0x9C9, quantity: 17, maxStack: 30)
        for layer in 0...1 {
            for (x, y) in [(0, 0), (286, 190)] {
                let index = try IslandLayout.fieldIndex(x: x, y: y, layer: layer)
                draft.island = try world.dropping(item, at: index, edits: draft.island)
            }
        }
        for index in draft.island.fieldItems.keys {
            let offset = IslandLayout.field + index * 8
            expectedRanges.append(offset..<(offset + 8))
        }
        let destination = root.appendingPathComponent("Corners")
        try session.export(draft, to: destination)
        let reopened = try SaveSession(folder: destination), changed = IslandSnapshot(main: reopened.main)
        for (index, tile) in draft.island.terrain { XCTAssertEqual(changed.terrain(index), tile) }
        for (index, item) in draft.island.fieldItems { XCTAssertEqual(changed.fieldItem(index), item) }
        assertOnlyChanges(session.main, reopened.main, ranges: expectedRanges)
        XCTAssertEqual(reopened.personal, session.personal)
        // Remove an existing, exported object through its last extension cell.
        let extensionIndex = try IslandLayout.fieldIndex(x: 287, y: 191, layer: 1)
        let removed = try changed.removingItem(at: extensionIndex, edits: .init())
        XCTAssertEqual(removed.fieldItems.count, 4)
        XCTAssertTrue(removed.fieldItems.values.allSatisfy(\.isEmpty))
        var secondDraft = reopened.initial; secondDraft.island = removed
        let secondDestination = root.appendingPathComponent("Removed")
        try reopened.export(secondDraft, to: secondDestination)
        let final = IslandSnapshot(main: try SaveSession(folder: secondDestination).main)
        for index in removed.fieldItems.keys { XCTAssertTrue(final.fieldItem(index).isEmpty) }
        XCTAssertEqual(final.fieldItem(try IslandLayout.fieldIndex(x: 286, y: 190, layer: 0)).id, item.id)
        XCTAssertEqual(final.fieldItem(try IslandLayout.fieldIndex(x: 0, y: 0, layer: 1)).id, item.id)
        try session.ensureUnchanged()
    }
    func testIslandAndVillagersSaveBackupRestore() throws {
        let session = try SaveSession(folder: folder), world = IslandSnapshot(main: session.main)
        var draft = session.initial, tile = world.terrain(100)
        tile.path = 0x94; draft.island.terrain[100] = tile
        var animal = world.villager(0); animal.catchphrase = "Testing"; draft.island.villagers[0] = animal
        let item = try PocketItem.make(id: 0x9C9, quantity: 3, maxStack: 30)
        draft.island = try world.dropping(item, at: IslandLayout.fieldIndex(x: 100, y: 100, layer: 0), edits: draft.island)
        let backupRoot = root.appendingPathComponent("Backups")
        let backup = try session.save(draft, backupRoot: backupRoot)
        try backup.verify()
        let changed = try SaveSession(folder: folder)
        XCTAssertEqual(IslandSnapshot(main: changed.main).terrain(100).path, 0x94)
        _ = try changed.restore(backup, backupRoot: backupRoot)
        XCTAssertEqual(try SaveSession(folder: folder).main, session.main)
    }
    func testRejectsInvalidMapFieldsAndDuplicateResidents() throws {
        let session = try SaveSession(folder: folder), world = IslandSnapshot(main: session.main)
        var draft = session.initial
        draft.island.terrain[112 * 96] = TerrainTile()
        XCTAssertThrowsError(try session.encoded(draft))
        draft.island = .init(); var tile = TerrainTile(); tile.ground = 2; draft.island.terrain[0] = tile
        XCTAssertThrowsError(try session.encoded(draft))
        draft.island = .init(); draft.island.buildings[0] = BuildingPosition(x: 288, y: 0, angle: 0)
        XCTAssertThrowsError(try session.encoded(draft))
        draft.island = .init(); draft.island.villagers[0] = world.villager(1)
        XCTAssertThrowsError(try session.encoded(draft))
        draft.island = .init(); draft.island.villagers[10] = world.villager(1)
        XCTAssertThrowsError(try session.encoded(draft))
        draft.island = .init(); var animal = world.villager(0); animal.variant = 255; draft.island.villagers[0] = animal
        XCTAssertThrowsError(try session.encoded(draft))
    }
    func testRejectsOccupiedDropsAndOutOfBoundsFootprints() throws {
        let world = IslandSnapshot.preview(), item = try PocketItem.make(id: 0x9C9, quantity: 1, maxStack: 30)
        let index = try IslandLayout.fieldIndex(x: 100, y: 80, layer: 0)
        let edits = try world.dropping(item, at: index, edits: .init())
        XCTAssertThrowsError(try world.dropping(item, at: index, edits: edits))
        XCTAssertThrowsError(try world.dropping(item, at: IslandLayout.fieldIndex(x: 287, y: 191, layer: 0), edits: .init()))
        XCTAssertThrowsError(try IslandLayout.terrainIndex(x: -1, y: 0))
        XCTAssertThrowsError(try IslandLayout.fieldIndex(x: 288, y: 0, layer: 0))
        XCTAssertThrowsError(try IslandLayout.fieldIndex(x: 0, y: 0, layer: 2))
    }
    func testUTF16LimitsAndEmptyMemoryGuards() throws {
        let session = try SaveSession(folder: folder), world = IslandSnapshot(main: session.main)
        var draft = session.initial, animal = world.villager(0)
        animal.catchphrase = String(repeating: "🌴", count: 13); draft.island.villagers[0] = animal
        XCTAssertThrowsError(try session.encoded(draft))
        animal.catchphrase = String(repeating: "🌴", count: 12); draft.island.villagers[0] = animal
        XCTAssertNoThrow(try session.encoded(draft))
        animal.friendship[1] = 200; draft.island.villagers[0] = animal
        XCTAssertThrowsError(try session.encoded(draft))
        draft.island = .init(); draft.island.villagers[3] = world.villager(0)
        XCTAssertThrowsError(try session.encoded(draft))
    }
    func testAllTenResidentsAndFirstLastMemoriesRoundTrip() throws {
        let seed = try SaveSession(folder: folder)
        var main = seed.main
        let template = main.subdata(in: 0x120..<(0x120 + 0x13230))
        let identities = Array(NHSEVillagerIDs.known.sorted().prefix(10))
        for index in 0..<10 {
            let offset = 0x120 + index * 0x13230
            main.replaceSubrange(offset..<(offset + 0x13230), with: template)
            main[offset] = UInt8(identities[index] / 256)
            main[offset + 1] = UInt8(identities[index] % 256)
            main[offset + 0x1267A] = index.isMultiple(of: 2) ? 0xA5 : 0xA7
            let memory = offset + 4 + 7 * 0x5F0
            main.replaceSubrange((memory + 0x20)..<(memory + 0x20 + 10), with: "Guest".data(using: .utf16LittleEndian)!)
        }
        SaveLayout.rehash(&main, regions: SaveLayout.mainRegions)
        try SaveCodec.crypt(main, header: Self.files["mainHeader.dat"]!).write(to: folder.appendingPathComponent("main.dat"))
        let session = try SaveSession(folder: folder), world = IslandSnapshot(main: session.main)
        var draft = session.initial
        var ranges: [Range<Int>] = []
        for index in 0..<10 {
            var animal = world.villager(index)
            // A simultaneous rotation of identities is valid: the final island has no duplicates.
            let identity = identities[(index + 1) % 10]
            animal.species = UInt8(identity / 256); animal.variant = UInt8(identity % 256)
            animal.personality = UInt8(index % 9)
            animal.catchphrase = index == 9 ? String(repeating: "🌴", count: 12) : "Resident \(index + 1)"
            animal.movingOut.toggle()
            animal.friendship[0] = index.isMultiple(of: 2) ? 0 : 255
            animal.friendship[7] = index.isMultiple(of: 2) ? 255 : 0
            draft.island.villagers[index] = animal
            let offset = 0x120 + index * 0x13230
            ranges += [offset..<(offset + 3), (offset + 0x10794)..<(offset + 0x107C4),
                       (offset + 0x1267A)..<(offset + 0x1267B), (offset + 0x46)..<(offset + 0x47),
                       (offset + 0x46 + 7 * 0x5F0)..<(offset + 0x47 + 7 * 0x5F0)]
        }
        let destination = root.appendingPathComponent("TenResidents")
        try session.export(draft, to: destination)
        let reopened = try SaveSession(folder: destination), changed = IslandSnapshot(main: reopened.main)
        for index in 0..<10 {
            XCTAssertEqual(changed.villager(index), draft.island.villagers[index])
            XCTAssertEqual(changed.memoryName(villager: index, memory: 0), "Player")
            XCTAssertEqual(changed.memoryName(villager: index, memory: 7), "Guest")
            let flag = 0x120 + index * 0x13230 + 0x1267A
            XCTAssertEqual(reopened.main[flag], session.main[flag] ^ 2)
        }
        XCTAssertEqual(reopened.personal, session.personal)
        assertOnlyChanges(session.main, reopened.main, ranges: ranges)
        try session.ensureUnchanged()
    }

    func testCatchphraseShorteningClearsTrailingUTF16Storage() throws {
        let session = try SaveSession(folder: folder), world = IslandSnapshot(main: session.main)
        var draft = session.initial, animal = world.villager(0)
        animal.catchphrase = String(repeating: "🌴", count: 12)
        draft.island.villagers[0] = animal
        let full = root.appendingPathComponent("FullPhrase")
        try session.export(draft, to: full)
        let reopened = try SaveSession(folder: full)
        XCTAssertEqual(IslandSnapshot(main: reopened.main).villager(0).catchphrase, animal.catchphrase)
        for text in ["é", ""] {
            var next = reopened.initial
            animal.catchphrase = text; next.island.villagers[0] = animal
            let output = try reopened.encoded(next)
            let plain = try SaveCodec.crypt(output["main.dat"]!, header: Self.files["mainHeader.dat"]!)
            let storage = plain.subdata(in: (0x120 + 0x10794)..<(0x120 + 0x107C4))
            let prefix = text.data(using: .utf16LittleEndian)!
            XCTAssertEqual(storage, prefix + Data(repeating: 0, count: 48 - prefix.count))
            XCTAssertEqual(IslandSnapshot(main: plain).villager(0).catchphrase, text)
        }
    }

    func testMalformedResidentDraftsCannotCreateAnExport() throws {
        let session = try SaveSession(folder: folder), world = IslandSnapshot(main: session.main)
        var invalid: [VillagerEdit] = []
        for size in [0, 7, 9] {
            var animal = world.villager(0); animal.friendship = Array(repeating: 0, count: size); invalid.append(animal)
        }
        var animal = world.villager(0); animal.personality = 9; invalid.append(animal)
        animal = world.villager(0); animal.catchphrase = "Hi\0there"; invalid.append(animal)
        animal = world.villager(0); animal.catchphrase = String(repeating: "🌴", count: 13); invalid.append(animal)
        for (index, record) in invalid.enumerated() {
            var draft = session.initial; draft.island.villagers[0] = record
            let destination = root.appendingPathComponent("Invalid\(index)")
            XCTAssertThrowsError(try session.export(draft, to: destination))
            XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        }
        for index in [-1, 10] {
            var draft = session.initial; draft.island.villagers[index] = world.villager(0)
            XCTAssertThrowsError(try session.encoded(draft))
        }
        try session.ensureUnchanged()
    }

    func testDuplicateResidentExportLeavesOriginalAndDestinationUntouched() throws {
        let session = try SaveSession(folder: folder), world = IslandSnapshot(main: session.main)
        var draft = session.initial
        draft.island.villagers[0] = world.villager(1)
        let destination = root.appendingPathComponent("DuplicateResident")
        XCTAssertThrowsError(try session.export(draft, to: destination)) { error in
            XCTAssertTrue(error.localizedDescription.contains("already lives"))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("main.dat")), Self.files["main.dat"])
        try session.ensureUnchanged()
    }
    func testBuildingPositionsBeyondOldCanvasLimitsSurviveExport() throws {
        let seed = try SaveSession(folder: folder)
        var main = seed.main
        let offset = IslandLayout.buildings + 3 * IslandLayout.buildingSize
        main.put16(10, at: offset)
        main.put16(124, at: offset + 2); main.put16(116, at: offset + 4)
        main.replaceSubrange((offset + 7)..<(offset + 20), with: Data((7..<20).map(UInt8.init)))
        SaveLayout.rehash(&main, regions: SaveLayout.mainRegions)
        try SaveCodec.crypt(main, header: Self.files["mainHeader.dat"]!).write(to: folder.appendingPathComponent("main.dat"))
        let session = try SaveSession(folder: folder)
        var draft = session.initial
        draft.island.buildings[3] = BuildingPosition(x: 126, y: 116, angle: 0)
        draft.island.buildings[0] = BuildingPosition(x: 219, y: 132, angle: 3)
        let destination = root.appendingPathComponent("BuildingGrid")
        try session.export(draft, to: destination)
        let reopened = try SaveSession(folder: destination), changed = IslandSnapshot(main: reopened.main)
        XCTAssertEqual(changed.building(3).kind, 10)
        XCTAssertEqual(changed.building(3).position, draft.island.buildings[3])
        XCTAssertEqual(changed.building(0).position, draft.island.buildings[0])
        XCTAssertEqual(reopened.personal, session.personal)
        assertOnlyChanges(session.main, reopened.main, ranges: [(offset + 2)..<(offset + 7), (IslandLayout.buildings + 2)..<(IslandLayout.buildings + 7)])
        try session.ensureUnchanged()
    }

    func testBuildingBoundsUseTheFull288By256Map() throws {
        let session = try SaveSession(folder: folder)
        var draft = session.initial
        let corner = BuildingPosition(x: 287, y: 255, angle: 3)
        draft.island.buildings[0] = corner
        let files = try session.encoded(draft)
        let main = try SaveCodec.crypt(files["main.dat"]!, header: Self.files["mainHeader.dat"]!)
        XCTAssertEqual(IslandSnapshot(main: main).building(0).position, corner)
        for invalid in [BuildingPosition(x: 288, y: 0, angle: 0), BuildingPosition(x: 0, y: 256, angle: 0), BuildingPosition(x: 0, y: 0, angle: 4)] {
            draft.island.buildings[0] = invalid
            XCTAssertThrowsError(try session.encoded(draft))
        }
    }
    private func assertOnlyChanges(_ before: Data, _ after: Data, ranges: [Range<Int>], file: StaticString = #filePath, line: UInt = #line) {
        var normalized = after
        for range in ranges + SaveLayout.mainRegions.map({ $0.offset..<($0.offset + 4) }) { normalized.replaceSubrange(range, with: before.subdata(in: range)) }
        XCTAssertTrue(normalized == before, "Unrelated island bytes were modified", file: file, line: line)
    }
}
