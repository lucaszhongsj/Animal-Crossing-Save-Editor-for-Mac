// Swift adaptation of NHSE.Core map / Villager2 structures, GPL-3.0.
// See THIRD-PARTY-NOTICES.md and REFERENCE-REVISION.txt for upstream provenance.
import Foundation

public enum IslandLayout {
    public static let terrain = 0x30AB00, width = 112, height = 96, tileSize = 14
    public static let field = 0x22F500, fieldWidth = 288, fieldHeight = 192
    public static let fieldCount = fieldWidth * fieldHeight, fieldLayerSize = fieldCount * 8
    public static let buildings = 0x32F700, buildingCount = 46, buildingSize = 20
    // Building positions use the full 9×8-acre map at 32 half-tiles per acre.
    public static let buildingWidth = 288, buildingHeight = 256
    public static let villagers = 0x120, villagerCount = 10, villagerSize = 0x13230
    public static let acres = 0x32FAAC
    // NHSE MainSave.EventPlazaLeftUpX/Z: OutsideField + 9*8*2 + 4/8.
    public static let plaza = acres + 9 * 8 * 2 + 4
    public static let plazaSelectionID = buildingCount
    public static func terrainIndex(x: Int, y: Int) throws -> Int {
        guard (0..<width).contains(x), (0..<height).contains(y) else { throw SaveError("Terrain coordinates are outside the island.") }
        return x * height + y
    }
    public static func fieldIndex(x: Int, y: Int, layer: Int) throws -> Int {
        guard (0..<fieldWidth).contains(x), (0..<fieldHeight).contains(y), (0...1).contains(layer) else { throw SaveError("Outdoor item coordinates are outside the map.") }
        return layer * fieldCount + x * fieldHeight + y
    }
}

public struct TerrainTile: Equatable {
    public var ground: UInt16 = 0, variation: UInt16 = 0, angle: UInt16 = 0
    public var path: UInt16 = 0, pathVariation: UInt16 = 0, pathAngle: UInt16 = 0, elevation: UInt16 = 0
    public init() {}
    public init(raw: Data) {
        ground = raw.u16(0); variation = raw.u16(2); angle = raw.u16(4)
        path = raw.u16(6); pathVariation = raw.u16(8); pathAngle = raw.u16(10); elevation = raw.u16(12)
    }
    public var raw: Data {
        var data = Data(repeating: 0, count: 14)
        for (i, value) in [ground, variation, angle, path, pathVariation, pathAngle, elevation].enumerated() { data.put16(value, at: i * 2) }
        return data
    }
    public var isWater: Bool { (1...0x15).contains(ground) || (0x3A...0x46).contains(ground) || (0x71...0x92).contains(ground) }
    public func validate() throws {
        let validGround = NHSETerrainModels.ground.contains(ground)
        let validPath = NHSETerrainModels.path.contains(path)
        guard validGround, validPath, angle < 4, pathAngle < 4, elevation <= 3 else { throw SaveError("A terrain tile has an invalid model, angle, or elevation.") }
    }
}

/// Separate uint32 coordinates in NHSE; the plaza is not a Building record.
public struct PlazaPosition: Equatable {
    public var x: UInt32, y: UInt32
    public init(x: UInt32, y: UInt32) { self.x = x; self.y = y }
}

public struct BuildingPosition: Equatable {
    public var x: UInt16, y: UInt16, angle: UInt8
    public init(x: UInt16, y: UInt16, angle: UInt8) { self.x = x; self.y = y; self.angle = angle }
}
public struct MapBuilding: Identifiable {
    public let id: Int
    public let kind: UInt16
    public var position: BuildingPosition
    public let subtype: UInt16
    public init(id: Int, kind: UInt16, position: BuildingPosition, subtype: UInt16 = 0) {
        self.id = id; self.kind = kind; self.position = position; self.subtype = subtype
    }
    public var name: String {
        if (1...8).contains(kind) { return "Player \(kind)’s house" }
        if (9...18).contains(kind) { return "Villager \(kind - 8)’s house" }
        return [19: "Nook’s Cranny", 20: "Resident Services", 21: "Museum", 22: "Airport", 23: "Resident Services tent", 24: "Able Sisters", 25: "Campsite", 26: "Bridge", 27: "Incline", 28: "Redd’s trawler", 29: "Studio", 42: "Hotel"][Int(kind)] ?? "Building \(kind)"
    }
}

public struct VillagerEdit: Equatable {
    public var species: UInt8, variant: UInt8, personality: UInt8
    public var catchphrase: String
    public var movingOut: Bool
    public var friendship: [UInt8]
    public var isEmpty: Bool { species >= 35 }
    public var identity: Int { Int(species) * 256 + Int(variant) }
    public static let personalities = ["Lazy", "Jock", "Cranky", "Smug", "Normal", "Peppy", "Snooty", "Sisterly", "None"]
    public init(species: UInt8, variant: UInt8, personality: UInt8, catchphrase: String, movingOut: Bool, friendship: [UInt8]) {
        self.species = species; self.variant = variant; self.personality = personality
        self.catchphrase = catchphrase; self.movingOut = movingOut; self.friendship = friendship
    }
}

public struct IslandEdits: Equatable {
    public var terrain: [Int: TerrainTile] = [:]
    public var fieldItems: [Int: PocketItem] = [:]
    public var buildings: [Int: BuildingPosition] = [:]
    public var bridgeTypes: [Int: UInt16] = [:]
    public var plaza: PlazaPosition?
    public var villagers: [Int: VillagerEdit] = [:]
    public init() {}
    public var isEmpty: Bool { terrain.isEmpty && fieldItems.isEmpty && buildings.isEmpty && bridgeTypes.isEmpty && plaza == nil && villagers.isEmpty }
    public func applying(to main: inout Data) throws {
        guard main.count == SaveLayout.mainSize else { throw SaveError("Unexpected island file size.") }
        let snapshot = IslandSnapshot(main: main)
        for (index, tile) in terrain {
            guard (0..<(IslandLayout.width * IslandLayout.height)).contains(index) else { throw SaveError("Invalid terrain index.") }
            try tile.validate()
            let offset = IslandLayout.terrain + index * 14
            main.replaceSubrange(offset..<(offset + 14), with: tile.raw)
        }
        for (index, item) in fieldItems {
            guard (0..<(IslandLayout.fieldCount * 2)).contains(index), item.raw.count == 8 else { throw SaveError("Invalid outdoor item record.") }
            let offset = IslandLayout.field + index * 8
            main.replaceSubrange(offset..<(offset + 8), with: item.raw)
            // A removed/replaced object must not retain an animation activation flag.
            let layer = index / IslandLayout.fieldCount, local = index % IslandLayout.fieldCount
            let x = local / IslandLayout.fieldHeight, y = local % IslandLayout.fieldHeight
            let flag = y * IslandLayout.fieldWidth + x
            let flagOffset = IslandLayout.field + IslandLayout.fieldLayerSize * 2 + layer * (IslandLayout.fieldCount / 8) + flag / 8
            main[flagOffset] &= ~(1 << (flag % 8))
        }
        for (index, position) in buildings {
            guard (0..<46).contains(index), snapshot.building(index).kind != 0,
                  position.x < IslandLayout.buildingWidth, position.y < IslandLayout.buildingHeight, position.angle < 4 else { throw SaveError("Invalid building position. Coordinates must be within the map (X: 0–287, Y: 0–255).") }
            let offset = IslandLayout.buildings + index * 20
            main.put16(position.x, at: offset + 2); main.put16(position.y, at: offset + 4); main[offset + 6] = position.angle
        }
        for (index, subtype) in bridgeTypes {
            guard (0..<IslandLayout.buildingCount).contains(index), snapshot.building(index).kind == 26,
                  let type = BridgeType(subtype) else { throw SaveError("Choose a known type for an existing bridge.") }
            let offset = IslandLayout.buildings + index * IslandLayout.buildingSize
            main.put16(type.id, at: offset + 8)
            main[offset + 10] = type.style.rawValue
        }
        if let plaza {
            // Match the original NHSE plaza controls, independently of building bounds.
            guard plaza.x <= 1024, plaza.y <= 1024 else { throw SaveError("Invalid plaza position. Coordinates must be between 0 and 1024.") }
            main.put32(plaza.x, at: IslandLayout.plaza)
            main.put32(plaza.y, at: IslandLayout.plaza + 4)
        }
        let finalVillagers = (0..<10).map { villagers[$0] ?? snapshot.villager($0) }
        for (index, villager) in villagers {
            guard (0..<10).contains(index), !snapshot.villager(index).isEmpty, NHSEVillagerIDs.known.contains(villager.identity), villager.personality <= 8, villager.friendship.count == 8,
                  villager.catchphrase.utf16.count <= 24, !villager.catchphrase.contains("\0") else { throw SaveError("Invalid villager record or catchphrase. Catchphrases allow 24 UTF-16 units.") }
            let original = snapshot.villager(index)
            if villager.identity != original.identity && finalVillagers.enumerated().contains(where: { $0.offset != index && !$0.element.isEmpty && $0.element.identity == villager.identity }) { throw SaveError("This villager already lives on your island.") }
            let offset = IslandLayout.villagers + index * IslandLayout.villagerSize
            if villager.species != original.species { main[offset] = villager.species }
            if villager.variant != original.variant { main[offset + 1] = villager.variant }
            if villager.personality != original.personality { main[offset + 2] = villager.personality }
            if villager.catchphrase != original.catchphrase {
                var text = Data(villager.catchphrase.data(using: .utf16LittleEndian)!)
                text.append(Data(repeating: 0, count: 48 - text.count))
                main.replaceSubrange((offset + 0x10794)..<(offset + 0x107C4), with: text)
            }
            if villager.movingOut != original.movingOut {
                main[offset + 0x1267A] = (main[offset + 0x1267A] & ~2) | (villager.movingOut ? 2 : 0)
            }
            for memory in 0..<8 where villager.friendship[memory] != original.friendship[memory] {
                guard !snapshot.memoryName(villager: index, memory: memory).isEmpty else { throw SaveError("Friendship can only be changed for an existing player memory.") }
                main[offset + 4 + memory * 0x5F0 + 0x42] = villager.friendship[memory]
            }
        }
    }
}

public struct IslandSnapshot {
    public let main: Data
    public init(main: Data) { precondition(main.count == SaveLayout.mainSize); self.main = main }
    public func terrain(_ index: Int, edits: IslandEdits = .init()) -> TerrainTile {
        if let tile = edits.terrain[index] { return tile }
        let offset = IslandLayout.terrain + index * 14
        return TerrainTile(raw: main.subdata(in: offset..<(offset + 14)))
    }
    public func fieldItem(_ index: Int, edits: IslandEdits = .init()) -> PocketItem {
        if let item = edits.fieldItems[index] { return item }
        let offset = IslandLayout.field + index * 8
        return PocketItem(raw: main.subdata(in: offset..<(offset + 8)))
    }
    public func plaza(edits: IslandEdits = .init()) -> PlazaPosition {
        edits.plaza ?? PlazaPosition(x: main.u32(IslandLayout.plaza), y: main.u32(IslandLayout.plaza + 4))
    }
    public func building(_ index: Int, edits: IslandEdits = .init()) -> MapBuilding {
        let offset = IslandLayout.buildings + index * 20
        return MapBuilding(id: index, kind: main.u16(offset), position: edits.buildings[index] ?? BuildingPosition(x: main.u16(offset + 2), y: main.u16(offset + 4), angle: main[offset + 6]), subtype: edits.bridgeTypes[index] ?? main.u16(offset + 8))
    }
    public func villager(_ index: Int, edits: IslandEdits = .init()) -> VillagerEdit {
        if let record = edits.villagers[index] { return record }
        let offset = IslandLayout.villagers + index * IslandLayout.villagerSize
        return VillagerEdit(species: main[offset], variant: main[offset + 1], personality: main[offset + 2], catchphrase: string(at: offset + 0x10794, units: 24), movingOut: main[offset + 0x1267A] & 2 != 0, friendship: (0..<8).map { main[offset + 4 + $0 * 0x5F0 + 0x42] })
    }
    public func memoryName(villager: Int, memory: Int) -> String { string(at: IslandLayout.villagers + villager * IslandLayout.villagerSize + 4 + memory * 0x5F0 + 0x20, units: 10) }
    private func string(at offset: Int, units: Int) -> String {
        let words = (0..<units).map { main.u16(offset + $0 * 2) }.prefix { $0 != 0 }
        return String(decoding: words, as: UTF16.self)
    }
    public func rootIndex(for index: Int, edits: IslandEdits) throws -> Int {
        guard (0..<(IslandLayout.fieldCount * 2)).contains(index) else { throw SaveError("Invalid item coordinates.") }
        let item = fieldItem(index, edits: edits)
        if item.id != 0xFFFD { return index }
        let local = index % IslandLayout.fieldCount, layer = index / IslandLayout.fieldCount
        let x = local / 192 - Int(item.raw[6]), y = local % 192 - Int(item.raw[7])
        let root = try IslandLayout.fieldIndex(x: x, y: y, layer: layer)
        guard fieldItem(root, edits: edits).id == item.raw.u16(4) else { throw SaveError("This item extension has no matching root.") }
        return root
    }
    public func removingItem(at index: Int, edits: IslandEdits) throws -> IslandEdits {
        let root = try rootIndex(for: index, edits: edits), item = fieldItem(root, edits: edits)
        var result = edits
        guard !item.isEmpty else { return result }
        let layer = root / IslandLayout.fieldCount, local = root % IslandLayout.fieldCount
        let x = local / 192, y = local % 192
        for i in 0..<IslandLayout.fieldCount {
            let key = layer * IslandLayout.fieldCount + i, candidate = fieldItem(key, edits: edits)
            if key == root || (candidate.id == 0xFFFD && candidate.raw.u16(4) == item.id && i / 192 - Int(candidate.raw[6]) == x && i % 192 - Int(candidate.raw[7]) == y) {
                result.fieldItems[key] = .empty
            }
        }
        return result
    }
    public func dropping(_ item: PocketItem, at index: Int, edits: IslandEdits) throws -> IslandEdits {
        guard (0..<(IslandLayout.fieldCount * 2)).contains(index), item.raw.count == 8, item.id > 0, item.id < 60_000 else { throw SaveError("Choose a regular catalog item.") }
        let local = index % IslandLayout.fieldCount, layer = index / IslandLayout.fieldCount
        let x = local / 192, y = local % 192
        var result = edits
        for dx in 0...1 { for dy in 0...1 {
            let key = try IslandLayout.fieldIndex(x: x + dx, y: y + dy, layer: layer)
            guard fieldItem(key, edits: edits).isEmpty else { throw SaveError("A dropped item needs an empty 2 × 2 space. Clear the existing object first.") }
            var raw: Data
            if dx == 0 && dy == 0 { raw = item.raw; raw[2] = 0x20; raw[3] = 0 }
            else {
                raw = Data(repeating: 0, count: 8); raw.put16(0xFFFD, at: 0); raw.put16(item.id, at: 4)
                raw[6] = UInt8(dx); raw[7] = UInt8(dy)
            }
            result.fieldItems[key] = PocketItem(raw: raw)
        } }
        return result
    }
    public static func preview() -> IslandSnapshot {
        var main = Data(repeating: 0, count: SaveLayout.mainSize)
        for layer in 0..<2 { for i in 0..<IslandLayout.fieldCount { main.put16(0xFFFE, at: IslandLayout.field + (layer * IslandLayout.fieldCount + i) * 8) } }
        for x in 0..<112 { for y in 0..<96 {
            var tile = TerrainTile()
            if abs(x - (55 + Int(8 * sin(Double(y) / 12)))) < 3 { tile.ground = 0x15 }
            if y < 30 && x > 64 && x < 90 { tile.elevation = 1 }
            if (y == 48 && (20...90).contains(x)) || (x == 40 && (35...70).contains(y)) { tile.path = 0x5C }
            let offset = IslandLayout.terrain + (x * 96 + y) * 14
            main.replaceSubrange(offset..<(offset + 14), with: tile.raw)
        } }
        // Show the bundled field-object artwork in the example island as well.
        for (x, y, id, layer) in [
            (84, 116, 60001, 0), (92, 116, 60009, 0), (100, 116, 60023, 0),
            (84, 124, 60260, 0), (88, 124, 60263, 0), (92, 124, 60266, 0),
            (96, 124, 60269, 0), (100, 124, 60284, 0),
            (84, 132, 60017, 0), (92, 132, 60020, 0), (100, 132, 60022, 0),
            (108, 124, 60262, 1)
        ] {
            let index = layer * IslandLayout.fieldCount + x * 192 + y
            main.put16(UInt16(id), at: IslandLayout.field + index * 8)
        }
        for i in 0..<10 { main[IslandLayout.villagers + i * IslandLayout.villagerSize] = 35 }
        for (index, species, variant, personality, phrase) in [(0, 4, 0, 4, "kablang"), (1, 10, 2, 0, "ruff ruff")] {
            let offset = IslandLayout.villagers + index * IslandLayout.villagerSize
            main[offset] = UInt8(species); main[offset + 1] = UInt8(variant); main[offset + 2] = UInt8(personality)
            let text = Data(phrase.data(using: .utf16LittleEndian)!)
            main.replaceSubrange((offset + 0x10794)..<(offset + 0x10794 + text.count), with: text)
            let name = Data("Player".data(using: .utf16LittleEndian)!)
            main.replaceSubrange((offset + 0x24)..<(offset + 0x24 + name.count), with: name)
            main[offset + 0x46] = 75
        }
        for (index, kind, x, y) in [
            (0,1,80,60), (1,19,140,60), (2,21,200,60),
            (3,9,80,90), (4,20,110,90), (5,22,160,90), (6,23,200,90),
            (7,24,80,150), (8,25,110,150), (9,26,150,150), (10,27,180,150),
            (11,28,80,190), (12,29,140,190), (13,42,200,190)
        ] {
            let offset = IslandLayout.buildings + index * 20
            main.put16(UInt16(kind), at: offset); main.put16(UInt16(x), at: offset + 2); main.put16(UInt16(y), at: offset + 4)
        }
        main.put32(98, at: IslandLayout.plaza); main.put32(92, at: IslandLayout.plaza + 4)
        return IslandSnapshot(main: main)
    }
}
