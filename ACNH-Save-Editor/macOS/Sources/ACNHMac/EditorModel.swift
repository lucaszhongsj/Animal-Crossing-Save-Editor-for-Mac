import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ACNHCore

struct CatalogItem: Identifiable {
    let id: UInt16
    let name: String
    let maxStack: Int
    var hex: String { String(format: "%04X", id) }
}

struct Catalog {
    let items: [CatalogItem]
    let byID: [UInt16: CatalogItem]
    static let favoriteNames: Set<String> = ["Nook Miles Ticket", "Bell bag", "Bell voucher", "99,000 Bells", "gold roses", "cherry-blossom petal", "star fragment", "large star fragment", "star wand", "gold nugget", "iron nugget", "pearl", "gold bars", "customization kit", "golden axe", "golden net", "golden rod", "golden shovel", "golden slingshot", "golden watering can", "crown (No Variations)", "royal crown (No Variations)"]
    init() {
        let text = (try? String(contentsOf: Bundle.module.url(forResource: "items", withExtension: "txt")!, encoding: .utf8)) ?? ""
        let limitsURL = Bundle.module.url(forResource: "stack-limits", withExtension: "json")!
        let limits = (try? JSONDecoder().decode([String: Int].self, from: Data(contentsOf: limitsURL))) ?? [:]
        let items = text.components(separatedBy: "\n").enumerated().compactMap { index, line -> CatalogItem? in
            let name = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard index > 0, index < 0xFFFD, !name.isEmpty, !name.hasPrefix("(None)") else { return nil }
            return CatalogItem(id: UInt16(index), name: name, maxStack: limits[String(index)] ?? 1)
        }
        self.items = items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        self.byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    }
    func name(_ slot: PocketItem, emptyLabel: String = "Empty pocket") -> String { slot.isEmpty ? emptyLabel : byID[slot.id]?.name ?? String(format: "Unknown item (%04X)", slot.id) }
    func quantity(_ slot: PocketItem) -> String {
        guard !slot.isEmpty, let item = byID[slot.id], item.maxStack > 1 else { return "" }
        return "×\(slot.storedCount + 1)"
    }
}

enum EditorPage: String, CaseIterable, Identifiable {
    case overview = "Overview", playerSettings = "Player Settings", islandSettings = "Island Settings", map = "Island Map", villagers = "Villagers", pockets = "Pockets", storage = "Storage", loadouts = "Loadouts", backups = "Backups"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .overview: "leaf"; case .playerSettings: "person.crop.circle"; case .islandSettings: "globe.americas"; case .map: "map"; case .villagers: "pawprint"; case .pockets: "square.grid.2x2"; case .storage: "archivebox"; case .loadouts: "tray.full"; case .backups: "clock.arrow.circlepath" }
    }
}

typealias Loadout = PocketLoadout

@MainActor final class EditorModel: ObservableObject {
    @Published var page: EditorPage? = .overview
    @Published var session: SaveSession?
    @Published var draft: SaveDraft?
    @Published var demo = false
    var previewDescription: String {
        "\(draft?.islandSettings.name ?? "Yolo") example island"
    }
    @Published var pocketSelection = InventorySelection(0)
    @Published var storageSelection = InventorySelection()
    @Published var selectedItem: UInt16?
    @Published var search = ""
    @Published var favoritesOnly = false
    @Published var quantity = 1
    @Published var error: String?
    @Published var status = "Open an exported save folder to begin."
    @Published var busy = false
    @Published var reviewing = false
    @Published var showGuide = false
    @Published var backups: [BackupRecord] = []
    @Published var loadouts: [Loadout?] = Array(repeating: nil, count: 5)
    @Published var history: [SaveDraft] = []
    @Published var future: [SaveDraft] = []
    @Published var previewWorld: IslandSnapshot?
    let catalog = Catalog()
    let loadoutNames = ["Mining", "Fishing", "Terraforming", "Custom 1", "Custom 2"]
    static let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ACNH Save Editor", isDirectory: true)
    var backupRoot: URL { Self.support.appendingPathComponent("Backups", isDirectory: true) }
    var isLoaded: Bool { draft != nil }
    var hasChanges: Bool { guard let draft, let session else { return false }; return draft != session.initial }
    var canUndo: Bool { !history.isEmpty && !busy }
    var currentItem: CatalogItem? { selectedItem.flatMap { catalog.byID[$0] } }
    var world: IslandSnapshot? { session.map { IslandSnapshot(main: $0.main) } ?? previewWorld }
    var filteredItems: [CatalogItem] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return catalog.items.filter { item in
            (!favoritesOnly || Catalog.favoriteNames.contains(item.name)) && (q.isEmpty || item.name.localizedCaseInsensitiveContains(q) || item.hex.caseInsensitiveCompare(q) == .orderedSame)
        }
    }
    var changes: [String] {
        guard let draft, let initial = session?.initial else { return [] }
        var result: [String] = []
        func describe<T: Equatable>(_ label: String, _ old: T, _ new: T, format: (T) -> String = { String(describing: $0) }) {
            if old != new { result.append("\(label): \(format(old)) → \(format(new))") }
        }
        let p = draft.playerSettings, oldP = initial.playerSettings
        let s = draft.islandSettings, oldS = initial.islandSettings
        describe("Player name", oldP.name, p.name)
        if oldP.birthMonth != p.birthMonth || oldP.birthDay != p.birthDay { result.append("Birthday: \(oldP.birthMonth)/\(oldP.birthDay) → \(p.birthMonth)/\(p.birthDay)") }
        describe("Island name", oldS.name, s.name)
        func option(_ value: UInt8, _ names: [String]) -> String { Int(value) < names.count ? names[Int(value)] : "Unknown (\(value))" }
        describe("Island hemisphere", oldS.hemisphere, s.hemisphere) { option($0, IslandSettings.hemispheres) }
        describe("Airport color", oldS.airportColor, s.airportColor) { option($0, IslandSettings.airportColors) }
        describe("Island weather seed", oldS.weatherSeed, s.weatherSeed)
        describe("Tour hemisphere", oldS.tourHemisphere, s.tourHemisphere) { option($0, IslandSettings.hemispheres) }
        describe("Tour weather seed", oldS.tourWeatherSeed, s.tourWeatherSeed)
        func fruit(_ value: UInt16) -> String { IslandSettings.fruits.first { $0.id == value }?.name ?? "Unknown (\(value))" }
        describe("Native fruit", oldS.nativeFruit, s.nativeFruit, format: fruit)
        describe("Sister fruit", oldS.sisterFruit, s.sisterFruit, format: fruit)
        describe("Native flower", oldS.nativeFlower, s.nativeFlower) { option($0, IslandSettings.flowers) }
        describe("Sister flower", oldS.sisterFlower, s.sisterFlower) { option($0, IslandSettings.flowers) }
        for i in 0..<4 where draft.economy[i] != initial.economy[i] {
            result.append("\(SaveDraft.labels[i]): \(initial.economy[i].formatted()) → \(draft.economy[i].formatted())")
        }
        for i in draft.pockets.indices where draft.pockets[i] != initial.pockets[i] {
            result.append("Pocket \(i + 1): \(catalog.name(initial.pockets[i])) → \(catalog.name(draft.pockets[i])) \(catalog.quantity(draft.pockets[i]))")
        }
        for i in draft.storage.indices where draft.storage[i] != initial.storage[i] {
            result.append("Storage slot \(i + 1): \(catalog.name(initial.storage[i], emptyLabel: "Empty slot")) \(catalog.quantity(initial.storage[i])) → \(catalog.name(draft.storage[i], emptyLabel: "Empty slot")) \(catalog.quantity(draft.storage[i]))")
        }
        let island = draft.island
        if !island.terrain.isEmpty { result.append("Map: \(island.terrain.count) terrain / path tiles edited") }
        if !island.fieldItems.isEmpty { result.append("Map: \(island.fieldItems.count) outdoor item cells edited, including linked footprint cells") }
        if let world {
            if let after = island.plaza {
                let before = world.plaza()
                result.append("Plaza: (\(before.x), \(before.y)) → (\(after.x), \(after.y))")
            }
            for index in island.bridgeTypes.keys.sorted() {
                let before = world.building(index).subtype, after = island.bridgeTypes[index]!
                result.append("Bridge [\(index + 1)]: \(BridgeType(before)?.name ?? "Type \(before)") → \(BridgeType(after)?.name ?? "Type \(after)")")
            }
            for index in island.buildings.keys.sorted() {
                let before = world.building(index), after = island.buildings[index]!
                result.append("\(before.name): (\(before.position.x), \(before.position.y)) → (\(after.x), \(after.y)), rotation \(Int(after.angle) * 90)°")
            }
            for index in island.villagers.keys.sorted() {
                let before = world.villager(index), after = island.villagers[index]!
                let name = IslandMetadata.shared.name(before)
                if before.identity != after.identity { result.append("Villager \(index + 1): \(name) → \(IslandMetadata.shared.name(after))") }
                if before.personality != after.personality { result.append("\(name): personality → \(VillagerEdit.personalities[Int(after.personality)])") }
                if before.catchphrase != after.catchphrase { result.append("\(name): catchphrase → “\(after.catchphrase)”") }
                if before.movingOut != after.movingOut { result.append("\(name): moving out → \(after.movingOut ? "Yes" : "No")") }
                if before.friendship != after.friendship { result.append("\(name): friendship edited") }
            }
        }
        return result
    }
    init() {
        reloadBackups()
        for i in 0..<5 {
            let url = Self.support.appendingPathComponent("Loadouts/\(i).json")
            if let data = try? Data(contentsOf: url), let saved = try? JSONDecoder().decode(Loadout.self, from: data), saved.isValid { loadouts[i] = saved }
        }
    }
    func reloadBackups() { backups = BackupRecord.list(root: backupRoot) }
    func change(recordUndo: Bool = true, _ mutate: (inout SaveDraft) -> Void) {
        guard !busy, var next = draft else { return }
        mutate(&next)
        if let world {
            if next.island.plaza == world.plaza() { next.island.plaza = nil }
            next.island.terrain = next.island.terrain.filter { world.terrain($0.key) != $0.value }
            next.island.fieldItems = next.island.fieldItems.filter { world.fieldItem($0.key) != $0.value }
            next.island.bridgeTypes = next.island.bridgeTypes.filter { world.building($0.key).subtype != $0.value }
            next.island.buildings = next.island.buildings.filter { world.building($0.key).position != $0.value }
            next.island.villagers = next.island.villagers.filter { world.villager($0.key) != $0.value }
        }
        guard next != draft else { return }
        if recordUndo { history.append(draft!); if history.count > 150 { history.removeFirst() } }
        future.removeAll(); draft = next
    }
    func undo() { guard let old = history.popLast(), let draft else { return }; future.append(draft); self.draft = old }
    func redo() { guard let next = future.popLast(), let draft else { return }; history.append(draft); self.draft = next }
    func revert() { guard let initial = session?.initial else { return }; change { $0 = initial } }
    func economyBinding(_ index: Int) -> Binding<UInt32> {
        Binding(get: { self.draft?.economy[index] ?? 0 }, set: { value in self.change { $0.economy[index] = min(value, SaveDraft.limits[index]) } })
    }
    func playerBinding<T>(_ key: WritableKeyPath<PlayerSettings, T>, fallback: T) -> Binding<T> {
        Binding(get: { self.draft?.playerSettings[keyPath: key] ?? fallback }, set: { value in self.change { $0.playerSettings[keyPath: key] = value } })
    }
    func islandBinding<T>(_ key: WritableKeyPath<IslandSettings, T>, fallback: T) -> Binding<T> {
        Binding(get: { self.draft?.islandSettings[keyPath: key] ?? fallback }, set: { value in self.change { $0.islandSettings[keyPath: key] = value } })
    }
    var settingsError: String? {
        guard let draft else { return nil }
        do { try SettingsLayout.validate(draft, initial: session?.initial ?? SaveDraft(economy: [], pockets: [])); return nil }
        catch { return error.localizedDescription }
    }
    func selectItem(_ id: UInt16) { selectedItem = id; quantity = 1 }
    func placeItem() { placeSelected(in: .pockets) }
    func placeStorageItem() { placeSelected(in: .storage) }
    private func placeSelected(in destination: InventoryDestination) {
        guard let item = currentItem, var next = draft else { return }
        let slots = destination == .pockets ? pocketSelection.indices : storageSelection.indices
        guard !slots.isEmpty else { return }
        do {
            let record = try PocketItem.make(id: item.id, quantity: quantity, maxStack: item.maxStack)
            try next.assign(record, to: slots, in: destination)
            change { $0 = next }
            status = "\(item.name) placed in \(slots.count) \(destination == .pockets ? "pocket" : "storage") slot(s). Review changes when ready."
        } catch { self.error = error.localizedDescription }
    }
    func clearSelected(in destination: InventoryDestination) {
        guard var next = draft else { return }
        let slots = destination == .pockets ? pocketSelection.indices : storageSelection.indices
        guard !slots.isEmpty else { return }
        do {
            try next.assign(.empty, to: slots, in: destination)
            change { $0 = next }
            status = "\(slots.count) selected slot(s) cleared in your draft."
        } catch { self.error = error.localizedDescription }
    }
    func clearStorageSlot(_ index: Int) {
        guard let draft, draft.storage.indices.contains(index) else { return }
        change { $0.storage[index] = .empty }
        status = "Storage slot \(index + 1) cleared in your draft."
    }
    func updateStorageQuantity(_ index: Int, quantity: Int) {
        guard let draft, draft.storage.indices.contains(index), let item = catalog.byID[draft.storage[index].id] else { return }
        do {
            let record = try draft.storage[index].changingQuantity(to: quantity, maxStack: item.maxStack)
            change { $0.storage[index] = record }
            status = "Quantity updated in storage slot \(index + 1)."
        } catch { self.error = error.localizedDescription }
    }
    func editVillager(_ index: Int, _ mutate: (inout VillagerEdit) -> Void) {
        guard let world else { return }
        change { draft in
            var record = world.villager(index, edits: draft.island)
            mutate(&record); draft.island.villagers[index] = record
        }
    }
    func dropMapItem(at index: Int) {
        guard let world, let draft, let item = currentItem else { return }
        do {
            let pocket = try PocketItem.make(id: item.id, quantity: quantity, maxStack: item.maxStack)
            let edits = try world.dropping(pocket, at: index, edits: draft.island)
            change { $0.island = edits }
            status = "\(item.name) added to the map draft."
        } catch { self.error = error.localizedDescription }
    }
    func copyMapItem(at index: Int) -> Data? {
        guard !busy, let world, let draft else { return nil }
        do {
            let copied = try world.copyingItem(at: index, edits: draft.island)
            let data = try JSONEncoder().encode(copied)
            status = "\(copied.rootItem.map { catalog.name($0) } ?? "Object") copied with its footprint."
            return data
        } catch { self.error = error.localizedDescription; return nil }
    }
    func pasteMapItem(_ data: Data, at index: Int) {
        guard !busy, let world, let draft else { return }
        do {
            guard data.count <= 1_048_576 else { throw SaveError("The copied map object is too large.") }
            let copied = try JSONDecoder().decode(MapItemClipboard.self, from: data)
            let edits = try world.pastingItem(copied, at: index, edits: draft.island)
            change { $0.island = edits }
            status = "Outdoor object pasted into the draft. Use ⌘Z to undo."
        } catch { self.error = error.localizedDescription }
    }
    func clearMapItem(at index: Int) {
        guard let world, let draft else { return }
        do {
            let edits = try world.removingItem(at: index, edits: draft.island)
            change { $0.island = edits }
            status = "Outdoor object and its linked footprint removed from the draft."
        }
        catch { self.error = error.localizedDescription }
    }
    func confirmDiscard() -> Bool {
        guard hasChanges else { return true }
        let alert = NSAlert()
        alert.messageText = "Discard unsaved changes?"
        alert.informativeText = "Your edits have not been exported or saved."
        alert.addButton(withTitle: "Keep Editing"); alert.addButton(withTitle: "Discard Changes")
        return alert.runModal() == .alertSecondButtonReturn
    }
    func chooseFolder() {
        guard !busy, confirmDiscard() else { return }
        let panel = NSOpenPanel()
        panel.title = "Open ACNH Save Folder"
        panel.message = "Choose the exported folder containing main.dat, mainHeader.dat, and Villager0."
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url { open(url) }
    }
    func open(_ url: URL) {
        perform("Checking save files…", operation: { try SaveSession(folder: url) }) { loaded in self.accept(loaded) }
    }
    private func accept(_ loaded: SaveSession) {
        session = loaded; draft = loaded.initial; demo = false; pocketSelection = InventorySelection(0); previewWorld = nil
        storageSelection = InventorySelection(loaded.initial.storage.isEmpty ? nil : 0)
        history.removeAll(); future.removeAll(); page = .overview
        status = "ACNH \(loaded.version) • Checksums verified • Primary resident"
        reloadBackups()
    }
    func openDemo() {
        guard confirmDiscard() else { return }
        guard let resource = Bundle.module.url(forResource: "ExampleSave", withExtension: nil) else {
            error = "The bundled example island is missing. Reinstall the app to restore it."
            return
        }
        do {
            let loaded = try SaveSession(folder: resource.appendingPathComponent("Save", isDirectory: true))
            // Keep no live SaveSession: previews cannot write or export the bundled snapshot.
            session = nil; draft = loaded.initial; demo = true
            previewWorld = IslandSnapshot(main: loaded.main)
            pocketSelection = InventorySelection(loaded.initial.pockets.isEmpty ? nil : 0)
            storageSelection = InventorySelection(loaded.initial.storage.isEmpty ? nil : 0)
            history.removeAll(); future.removeAll(); page = .overview
            status = "Preview · \(loaded.initial.islandSettings.name) · ACNH \(loaded.version) · Export and save disabled"
        } catch {
            self.error = "Could not load the example island: \(error.localizedDescription)"
        }
    }
    func export() {
        guard let session, let draft, !busy else { return }
        let panel = NSSavePanel()
        panel.title = "Export Edited Save"
        panel.message = "The complete save will be copied to a new folder. Import that folder using your Switch save manager."
        panel.nameFieldStringValue = session.folder.lastPathComponent + " — Edited"
        panel.directoryURL = session.folder.deletingLastPathComponent()
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        reviewing = false
        perform("Exporting and verifying edited copy…", operation: { try session.export(draft, to: destination); return destination }) { url in
            self.status = "Edited save exported to \(url.lastPathComponent). Original save preserved."
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
    func saveInPlace() {
        guard let session, let draft, hasChanges, !busy else { return }
        reviewing = false
        let root = backupRoot
        perform("Creating verified backup and saving…", operation: {
            let backup = try session.save(draft, backupRoot: root)
            return (try SaveSession(folder: session.folder), backup)
        }) { loaded, _ in self.accept(loaded); self.status = "Saved successfully. A verified backup is available in Backups." }
    }
    func restore(_ backup: BackupRecord) {
        guard let session, !busy else { return }
        let alert = NSAlert()
        alert.messageText = "Restore this backup?"
        alert.informativeText = "The opened save’s island, villagers, money, and pockets will return to this backup. The current files will be backed up first. Unsaved edits will be discarded."
        alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Restore Backup")
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        let root = backupRoot
        perform("Verifying and restoring backup…", operation: {
            _ = try session.restore(backup, backupRoot: root)
            return try SaveSession(folder: session.folder)
        }) { loaded in self.accept(loaded); self.page = .backups; self.status = "Backup restored. The previous files were also backed up." }
    }
    func openBackup(_ backup: BackupRecord) {
        guard confirmDiscard() else { return }
        perform("Verifying backup…", operation: { try backup.verify(); return try SaveSession(folder: backup.saveFolder) }) { loaded in self.accept(loaded); self.status = "Backup opened. Export a copy to recover it." }
    }
    func saveLoadout(_ index: Int) {
        guard let draft else { return }
        let loadout = Loadout(name: loadoutNames[index], pockets: draft.pockets)
        do {
            let folder = Self.support.appendingPathComponent("Loadouts", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try JSONEncoder().encode(loadout).write(to: folder.appendingPathComponent("\(index).json"), options: .atomic)
            loadouts[index] = loadout; status = "\(loadout.name) loadout saved on this Mac."
        } catch { self.error = error.localizedDescription }
    }
    func applyLoadout(_ index: Int) {
        guard let loadout = loadouts[index], let draft else { return }
        do {
            let pockets = try loadout.applying(to: draft.pockets)
            change { $0.pockets = pockets }
            let remaining = pockets.count - loadout.pockets.count
            status = "\(loadout.name): \(loadout.pockets.count) pockets applied to your draft." + (remaining > 0 ? " The remaining \(remaining) pockets are preserved." : "")
        } catch { self.error = error.localizedDescription }
    }
    func perform<T>(_ message: String, operation: @escaping () throws -> T, completion: @escaping (T) -> Void) {
        guard !busy else { return }
        busy = true; status = message
        Task {
            do {
                let value = try await Task.detached(priority: .userInitiated) { try operation() }.value
                busy = false; completion(value)
            } catch { busy = false; self.error = error.localizedDescription; status = "Operation stopped. \(error.localizedDescription)"; reloadBackups() }
        }
    }
}
