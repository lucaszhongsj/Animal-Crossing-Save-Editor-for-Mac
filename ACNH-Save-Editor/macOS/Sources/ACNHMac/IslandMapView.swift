import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ACNHCore

private enum MapLayer: String, CaseIterable { case terrain = "Terrain", items = "Items", buildings = "Buildings" }
private enum MapTool: String, CaseIterable { case inspect = "Inspect", ground = "Paint Terrain", path = "Paint Paths" }

struct IslandMapView: View {
    @EnvironmentObject var model: EditorModel
    @State private var layer: MapLayer = .terrain
    @State private var tool: MapTool = .inspect
    @State private var x = 40
    @State private var y = 40
    @State private var itemX = 112
    @State private var itemY = 80
    @State private var itemLayer = 0
    @State private var snapToGrid = true
    @State private var showSnapHelp = false
    @State private var selectedBuilding = 0
    @State private var zoomScale: Double = 1
    @State private var isPinching = false
    private var zoom: Double { MapZoom.pointsPerTile * zoomScale }
    @State private var grid = false
    @State private var showBuildings = true
    @State private var showItems = true
    @State private var showBuildingGuides = true
    @State private var ground: UInt16 = 0
    @State private var path: UInt16 = 0x5C
    @State private var angle: UInt16 = 0
    @State private var elevation: UInt16 = 0
    @State private var brushSize = 1
    @State private var strokeRecorded = false
    @State private var previousPoint: (Int, Int)?
    @State private var itemSearch = ""
    @FocusState private var mapFocused: Bool
    private static let mapItemType = UTType(exportedAs: "com.nhse-for-mac.outdoor-object", conformingTo: .data)
    private static let mapPasteboardType = NSPasteboard.PasteboardType(mapItemType.identifier)
    private static let acres = (try? Data(contentsOf: Bundle.module.url(forResource: "outside", withExtension: "bin")!)) ?? Data()
    private var edits: IslandEdits { model.draft?.island ?? .init() }
    private var selectedIndex: Int { x * 96 + y }
    private var selectedItemIndex: Int { itemLayer * IslandLayout.fieldCount + itemX * 192 + itemY }
    private var tile: TerrainTile { model.world?.terrain(selectedIndex, edits: edits) ?? TerrainTile() }
    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("An island of your own.").font(.system(size: 27, weight: .semibold, design: .rounded))
                    Text(model.demo ? "Preview · \(model.draft?.islandSettings.name ?? "Island") · Saving disabled" : "Select a tile to inspect it, or drag a brush to shape terrain and paths.")
                        .font(.callout).foregroundStyle(.secondary)
                    Text(layer == .buildings
                         ? "Click a building to select it · Pinch to zoom"
                         : "Click the map, then use ↑ ↓ ← → to select a tile · Pinch to zoom")
                        .font(.callout).foregroundStyle(.secondary)
                    Text("Items tab: ⌘C copy · ⌘V paste into empty space · Delete remove object · ⌘Z undo")
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Picker("Layer", selection: $layer) { ForEach(MapLayer.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).frame(maxWidth: 300)
                    Spacer()
                    Toggle("Grid", isOn: $grid).toggleStyle(.checkbox)
                }
                ViewThatFits(in: .horizontal) {
                    HStack {
                        zoomControls
                        Spacer(minLength: 12)
                        visibilityControls
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { zoomControls; Spacer(minLength: 0) }
                        HStack { Spacer(); visibilityControls }
                    }
                }.font(.caption)
                if let world = model.world {
                    MapZoomScrollView(scale: $zoomScale, isPinching: $isPinching,
                                      mapSize: NSSize(width: 144 * MapZoom.pointsPerTile, height: 128 * MapZoom.pointsPerTile),
                                      onPointerBegan: {
                                          isPinching = false
                                          mapFocused = true
                                          previousPoint = nil
                                          strokeRecorded = false
                                      },
                                      onPointer: { selectMapPoint($0, world: world) },
                                      onPointerEnded: { previousPoint = nil; strokeRecorded = false }) {
                        // Render at the visible resolution while the native document
                        // stays fixed, keeping artwork crisp without relaying out scrolling.
                        mapCanvas(world).frame(width: 144 * zoom, height: 128 * zoom)
                            .scaleEffect(1 / zoomScale, anchor: .topLeading)
                            .frame(width: 144 * MapZoom.pointsPerTile, height: 128 * MapZoom.pointsPerTile, alignment: .topLeading)
                    }
                    .background(Color(red: 0.48, green: 0.76, blue: 0.77))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                HStack(spacing: 12) {
                    legend("Land", color: .init(red: 0.30, green: 0.55, blue: 0.31))
                    legend("Water", color: .init(red: 0.50, green: 0.84, blue: 0.77))
                    legend("Path", color: .gray)
                    Spacer()
                    Text("NHSE map data · Schematic view").font(.caption2).foregroundStyle(.secondary)
                }
            }.padding(22).frame(minWidth: 490, maxWidth: .infinity)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch layer {
                    case .terrain: terrainInspector
                    case .items: itemInspector
                    case .buildings: buildingInspector
                    }
                }.padding(20)
            }.frame(minWidth: 290, idealWidth: 315, maxWidth: 370)
        }
        .onChange(of: layer) { _, newLayer in
            tool = .inspect; previousPoint = nil; strokeRecorded = false
            showSnapHelp = false
            if newLayer == .items && snapToGrid { selectItemCell(MapCell(x: itemX, y: itemY)) }
        }
        .onChange(of: snapToGrid) { _, enabled in
            if enabled { selectItemCell(MapCell(x: itemX, y: itemY)) }
        }
        .onChange(of: itemLayer) { _, _ in
            if snapToGrid { selectItemCell(MapCell(x: itemX, y: itemY)) }
        }
        .onChange(of: isPinching) { _, _ in
            previousPoint = nil
            strokeRecorded = false
        }
    }
    private var zoomControls: some View {
        HStack(spacing: 8) {
            Image(systemName: "minus.magnifyingglass")
            VStack(spacing: 2) {
                Slider(value: $zoomScale, in: 1...5, step: 1)
                    .accessibilityLabel("Map zoom")
                    .accessibilityValue("\(Int((zoomScale * 100).rounded())) percent")
                HStack(spacing: 0) {
                    ForEach(Array(MapZoom.stops), id: \.self) { stop in
                        if stop > 1 { Spacer(minLength: 0) }
                        Text("\(stop * 100)%").font(.system(size: 9).monospacedDigit())
                    }
                }.foregroundStyle(.secondary).accessibilityHidden(true)
            }.frame(width: 180).help("Pinch freely between 100% and 500%. Use the slider for 100%, 200%, 300%, 400%, or 500% presets.")
            Image(systemName: "plus.magnifyingglass")
            Text("\(Int((zoomScale * 100).rounded()))%").font(.caption.monospacedDigit()).frame(width: 38, alignment: .leading)
            if layer == .items { snapControls }
        }.fixedSize(horizontal: true, vertical: false)
    }
    private var visibilityControls: some View {
        HStack {
            Toggle("Objects", isOn: Binding(get: { showItems || layer == .items }, set: { showItems = $0 }))
                .toggleStyle(.checkbox).disabled(layer == .items)
            Toggle("Buildings", isOn: $showBuildings).toggleStyle(.checkbox)
        }.fixedSize()
    }
    private var snapControls: some View {
        HStack(spacing: 6) {
            Toggle("Snap to tiles", isOn: $snapToGrid).toggleStyle(.checkbox).fixedSize()
            Button { showSnapHelp.toggle() } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("About Snap to tiles")
            .help("About Snap to tiles")
            .popover(isPresented: $showSnapHelp) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Snap to tiles").font(.headline)
                    Text("Select object roots and move one full tile per arrow press. Turn off for finer positioning.")
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                }.frame(width: 250, alignment: .leading).padding(16)
            }
        }
    }
    private func moveSelection(_ direction: MoveCommandDirection) {
        guard mapFocused, !isPinching, !model.busy, layer != .buildings else { return }
        let dx: Int, dy: Int
        switch direction {
        case .left: (dx, dy) = (-1, 0)
        case .right: (dx, dy) = (1, 0)
        case .up: (dx, dy) = (0, -1)
        case .down: (dx, dy) = (0, 1)
        @unknown default: return
        }
        if layer == .items {
            moveItemSelection(dx: dx, dy: dy)
        } else {
            x = min(111, max(0, x + dx)); y = min(95, max(0, y + dy))
        }
        previousPoint = nil; strokeRecorded = false
    }
    private func moveItemSelection(dx: Int, dy: Int) {
        let next = MapCoordinates.movingItemCell(MapCell(x: itemX, y: itemY), dx: dx, dy: dy, snapped: snapToGrid)
        itemX = next.x; itemY = next.y
    }
    private func selectItemCell(_ cell: MapCell) {
        let next = snapToGrid ? MapCoordinates.snappedItemCell(cell) : cell
        if snapToGrid, let world = model.world {
            // Prefer the object actually clicked; an aligned cell may also be an extension.
            for candidate in [cell, next] {
                guard let index = try? IslandLayout.fieldIndex(x: candidate.x, y: candidate.y, layer: itemLayer),
                      let root = try? world.rootIndex(for: index, edits: edits),
                      !world.fieldItem(root, edits: edits).isEmpty else { continue }
                let local = root % IslandLayout.fieldCount
                itemX = local / 192; itemY = local % 192
                return
            }
        }
        itemX = next.x; itemY = next.y
    }
    private func copyProviders() -> [NSItemProvider] {
        guard layer == .items, let data = model.copyMapItem(at: selectedItemIndex) else { return [] }
        return [NSItemProvider(item: data as NSData, typeIdentifier: Self.mapItemType.identifier)]
    }
    private func pasteProviders(_ providers: [NSItemProvider]) {
        guard layer == .items, let provider = providers.first, let origin = model.world?.main else { return }
        let target = selectedItemIndex
        provider.loadDataRepresentation(forTypeIdentifier: Self.mapItemType.identifier) { data, error in
            Task { @MainActor in
                guard layer == .items, model.page == .map, model.world?.main == origin else { return }
                if let data { model.pasteMapItem(data, at: target) }
                else { model.error = error?.localizedDescription ?? "The clipboard does not contain an outdoor object." }
            }
        }
    }
    private func copyToPasteboard() {
        guard layer == .items, let data = model.copyMapItem(at: selectedItemIndex) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(data, forType: Self.mapPasteboardType)
    }
    private func pasteFromPasteboard() {
        guard layer == .items else { return }
        guard let data = NSPasteboard.general.data(forType: Self.mapPasteboardType) else {
            model.error = "Copy an outdoor object from the Items tab first."
            return
        }
        model.pasteMapItem(data, at: selectedItemIndex)
    }
    private func legend(_ text: String, color: Color) -> some View {
        HStack(spacing: 4) { Circle().fill(color).frame(width: 8, height: 8); Text(text).font(.caption2).foregroundStyle(.secondary) }
    }
    private var terrainInspector: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Terrain & Paths").font(.title3.weight(.semibold))
            Picker("Tool", selection: $tool) { ForEach(MapTool.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
            if tool != .inspect {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Brush").font(.headline)
                    if tool == .ground {
                        HStack {
                            Button("Grass") { ground = 0 }
                            Button("Water") { ground = 0x15 }
                            Button("Cliff") { ground = 0x29; elevation = max(1, elevation) }
                        }.controlSize(.small)
                        modelPicker("Shape", selection: $ground, road: false)
                        Stepper("Elevation: \(elevation)", value: $elevation, in: 0...3)
                    } else { pathPicker($path) }
                    rotation($angle)
                    Picker("Brush size", selection: $brushSize) { Text("1 × 1").tag(1); Text("3 × 3").tag(3); Text("5 × 5").tag(5) }
                    Text("Drag on the map to paint. A complete stroke is one undo step.").font(.caption).foregroundStyle(.secondary)
                }.padding(14).background(Color.island.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            }
            Divider()
            Text("Selected tile").font(.headline)
            HStack {
                Stepper("X: \(x)", value: $x, in: 0...111)
                Stepper("Y: \(y)", value: $y, in: 0...95)
            }.font(.callout)
            modelPicker("Terrain", selection: terrainBinding(\.ground), road: false)
            Stepper("Elevation: \(tile.elevation)", value: terrainBinding(\.elevation), in: 0...3)
            Picker("Terrain rotation", selection: terrainBinding(\.angle)) { ForEach(0..<4) { Text("\($0 * 90)°").tag(UInt16($0)) } }
            pathPicker(terrainBinding(\.path))
            Picker("Path rotation", selection: terrainBinding(\.pathAngle)) { ForEach(0..<4) { Text("\($0 * 90)°").tag(UInt16($0)) } }
            if edits.terrain[selectedIndex] != nil {
                Button("Revert This Tile") { model.change { $0.island.terrain.removeValue(forKey: selectedIndex) } }
            }
            Text("Terrain and path layers are edited independently. Base shoreline acres, custom designs, and untouched cells are preserved.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private func terrainBinding(_ key: WritableKeyPath<TerrainTile, UInt16>) -> Binding<UInt16> {
        Binding(get: { tile[keyPath: key] }, set: { value in
            guard let world = model.world else { return }
            model.change { draft in
                var valueTile = world.terrain(selectedIndex, edits: draft.island)
                valueTile[keyPath: key] = value
                if key == \.ground { valueTile.variation = 0 }
                if key == \.path { valueTile.pathVariation = 0 }
                draft.island.terrain[selectedIndex] = valueTile
            }
        })
    }
    private func modelPicker(_ title: String, selection: Binding<UInt16>, road: Bool) -> some View {
        Picker(title, selection: selection) {
            if road { Text("No path").tag(UInt16(0)) }
            ForEach(IslandMetadata.shared.terrain.filter { $0.road == road }) { choice in Text(friendly(choice.name)).tag(choice.id) }
        }
    }
    private func friendly(_ name: String) -> String {
        if name == "Base" { return "Flat grass" }
        return name.replacingOccurrences(of: "Road", with: "").replacingOccurrences(of: "DarkSoil", with: "Dark soil ").replacingOccurrences(of: "FanPattern", with: "Arched tile ")
            .replacingOccurrences(of: "River", with: "River ").replacingOccurrences(of: "Cliff", with: "Cliff ").replacingOccurrences(of: "Fall", with: "Waterfall ")
    }
    private func pathPicker(_ binding: Binding<UInt16>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Path style", selection: Binding(get: { pathBase(binding.wrappedValue) }, set: { binding.wrappedValue = $0 })) {
                ForEach(Array([(UInt16(0), "None"), (0x47, "Dirt"), (0x5C, "Stone"), (0x94, "Brick"), (0xA9, "Dark dirt"), (0xBE, "Arched tile"), (0xD3, "Sand"), (0xE8, "Tile"), (0xFD, "Wood")].enumerated()), id: \.offset) { _, entry in Text(entry.1).tag(entry.0) }
            }
            modelPicker("Path shape", selection: binding, road: true)
        }
    }
    private func pathBase(_ value: UInt16) -> UInt16 {
        if value == 0 { return 0 }
        return [UInt16(0xFD), 0xE8, 0xD3, 0xBE, 0xA9, 0x94, 0x5C, 0x47].first { value >= $0 } ?? 0
    }
    private func rotation(_ binding: Binding<UInt16>) -> some View {
        Picker("Rotation", selection: binding) { ForEach(0..<4) { Text("\($0 * 90)°").tag(UInt16($0)) } }
    }
    private var itemInspector: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Outdoor Items").font(.title3.weight(.semibold))
            Picker("Item layer", selection: $itemLayer) { Text("Ground").tag(0); Text("Upper").tag(1) }.pickerStyle(.segmented)
            HStack {
                Stepper("X: \(itemX)", onIncrement: { moveItemSelection(dx: 1, dy: 0) }, onDecrement: { moveItemSelection(dx: -1, dy: 0) }).accessibilityValue("\(itemX)")
                Stepper("Y: \(itemY)", onIncrement: { moveItemSelection(dx: 0, dy: 1) }, onDecrement: { moveItemSelection(dx: 0, dy: -1) }).accessibilityValue("\(itemY)")
            }.font(.callout)
            if let world = model.world {
                let root = (try? world.rootIndex(for: selectedItemIndex, edits: edits)) ?? selectedItemIndex
                let item = world.fieldItem(root, edits: edits)
                HStack(spacing: 10) {
                    if !item.isEmpty { ItemIcon(id: item.id, size: 40) }
                    Text(item.isEmpty ? "Empty map cell" : model.catalog.name(item)).font(.headline)
                }
                if !item.isEmpty {
                    Text("Root at (\((root % IslandLayout.fieldCount) / 192), \(root % 192))").font(.caption.monospaced()).foregroundStyle(.secondary)
                }
                HStack {
                    Button("Copy") { copyToPasteboard() }.disabled(item.isEmpty || model.busy).help("Copy object and footprint (⌘C)")
                    Button("Paste") { pasteFromPasteboard() }.disabled(model.busy).help("Paste into empty space (⌘V)")
                    Button("Delete") { model.clearMapItem(at: selectedItemIndex) }.disabled(item.isEmpty || model.busy).help("Delete object and footprint (Delete)")
                }
            }
            Divider()
            Text("Drop a catalog item").font(.headline)
            TextField("Search items", text: $itemSearch).textFieldStyle(.roundedBorder).accessibilityLabel("Search outdoor items")
            List(selection: Binding(get: { model.selectedItem }, set: { if let id = $0 { model.selectItem(id) } })) {
                ForEach(model.catalog.items.filter { $0.id < 60_000 && (itemSearch.isEmpty ? Catalog.favoriteNames.contains($0.name) : $0.name.localizedCaseInsensitiveContains(itemSearch)) }) { item in
                    HStack(spacing: 8) {
                        ItemIcon(id: item.id, size: 24)
                        Text(item.name).font(.callout)
                    }.tag(item.id)
                }
            }.listStyle(.bordered).frame(height: 200)
            if let item = model.currentItem {
                HStack(spacing: 10) {
                    ItemIcon(id: item.id, size: 36)
                    Text(item.name).font(.callout.weight(.semibold))
                }
                Stepper("Quantity: \(model.quantity)", value: $model.quantity, in: 1...max(1, item.maxStack))
                Button("Drop at Selected Cell") { model.dropMapItem(at: selectedItemIndex) }.buttonStyle(.borderedProminent)
            }
            Text("Items use half-tile coordinates. Dropping requires an empty 2 × 2 footprint; linked cells are added automatically. Terrain, building collision, and accessibility are not automatically resolved.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private var buildingInspector: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Buildings").font(.title3.weight(.semibold))
            if let world = model.world {
                let buildings = (0..<IslandLayout.buildingCount).map { world.building($0, edits: edits) }.filter { $0.kind != 0 }
                Group {
                    Picker("Building", selection: $selectedBuilding) {
                        Text("Plaza").tag(IslandLayout.plazaSelectionID)
                        ForEach(buildings) { building in Text("\(building.name) [\(building.id + 1)]").tag(building.id) }
                    }
                    if selectedBuilding == IslandLayout.plazaSelectionID || buildings.isEmpty {
                        plazaInspector(world)
                    } else {
                        let index = buildings.contains(where: { $0.id == selectedBuilding }) ? selectedBuilding : buildings[0].id
                        let building = world.building(index, edits: edits)
                        HStack(spacing: 12) {
                            BuildingIcon(kind: building.kind)
                            Text(building.name).font(.headline)
                        }
                        if let footprint = BuildingFootprint.forBuilding(building) {
                            Text("\(Int(footprint.width)) × \(Int(footprint.depth)) tile plot guide").font(.callout.weight(.medium))
                            Text("Dashed outline: one-tile spacing guide.").font(.caption).foregroundStyle(.secondary)
                            Text(footprint.note).font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("Plot dimensions not verified for this structure. Icon size is illustrative.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if building.kind == 26 { bridgeStyleInspector(building) }
                        Toggle("Show plot guides", isOn: $showBuildingGuides).toggleStyle(.checkbox)
                        Text("Coordinates in half tiles").font(.caption).foregroundStyle(.secondary)
                        Stepper("X: \(building.position.x)", value: buildingBinding(index, \.x), in: 0...UInt16(IslandLayout.buildingWidth - 1))
                        Stepper("Y: \(building.position.y)", value: buildingBinding(index, \.y), in: 0...UInt16(IslandLayout.buildingHeight - 1))
                        Picker("Rotation", selection: Binding(get: { Int(building.position.angle) }, set: { value in
                            model.change { draft in var p = building.position; p.angle = UInt8(value); draft.island.buildings[index] = p }
                        })) { ForEach(0..<4) { Text("\($0 * 90)°").tag($0) } }
                        if edits.buildings[index] != nil || edits.bridgeTypes[index] != nil {
                            Button("Revert Building") { model.change {
                                $0.island.buildings.removeValue(forKey: index)
                                $0.island.bridgeTypes.removeValue(forKey: index)
                            } }
                        }
                        Text("Each X or Y step moves the building half a terrain tile. Moving a building preserves its identity, interior, and other settings. Place it on clear, accessible land; collision and bridge/incline connections need manual checking.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    @ViewBuilder private func bridgeStyleInspector(_ building: MapBuilding) -> some View {
        if let type = BridgeType(building.subtype) {
            Picker("Bridge style", selection: Binding(get: { type.style }, set: { style in
                model.change { $0.island.bridgeTypes[building.id] = type.replacingStyle(with: style).id }
            })) {
                ForEach(BridgeStyle.allCases.filter { $0 != .reserved || type.style == .reserved }) { style in
                    Text(style.name).tag(style)
                }
            }
            Text("Changing style preserves the span, direction, position, and rotation, and updates the matching bridge material.")
                .font(.caption).foregroundStyle(.secondary)
            if edits.bridgeTypes[building.id] != nil {
                Button("Revert Bridge Style") { model.change { $0.island.bridgeTypes.removeValue(forKey: building.id) } }
            }
        } else {
            Text("Unknown bridge type (\(building.subtype)). Style changes require a recognized bridge model.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private func plazaInspector(_ world: IslandSnapshot) -> some View {
        let position = world.plaza(edits: edits)
        return VStack(alignment: .leading, spacing: 16) {
            Label("Plaza", systemImage: "square.grid.3x3.fill").font(.headline)
            Text("12 × 10 tile plaza · Upper-left anchor").font(.callout.weight(.medium))
            Stepper("X: \(position.x)", value: plazaBinding(\.x), in: 0...1024)
            Stepper("Y: \(position.y)", value: plazaBinding(\.y), in: 0...1024)
            if edits.plaza != nil {
                Button("Revert Plaza") { model.change { $0.island.plaza = nil } }
            }
            Text("Each step moves the plaza half a terrain tile. Resident Services is a separate building; move it separately if needed. The plaza has no rotation. Check terrain, objects, and accessibility at the destination in game.")
                .font(.caption).foregroundStyle(.secondary)
            Text("Coordinates match NHSE’s 0–1024 range. Positions outside the visible island can be edited here. The outline is a size guide; alignment needs in-game verification.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private func plazaBinding(_ key: WritableKeyPath<PlazaPosition, UInt32>) -> Binding<UInt32> {
        Binding(get: { model.world?.plaza(edits: edits)[keyPath: key] ?? 0 }, set: { value in
            guard let world = model.world else { return }
            model.change { draft in
                var position = world.plaza(edits: draft.island)
                position[keyPath: key] = value
                draft.island.plaza = position
            }
        })
    }
    private func buildingBinding(_ index: Int, _ key: WritableKeyPath<BuildingPosition, UInt16>) -> Binding<UInt16> {
        Binding(get: { model.world?.building(index, edits: edits).position[keyPath: key] ?? 0 }, set: { value in
            guard let world = model.world else { return }
            model.change { draft in var p = world.building(index, edits: draft.island).position; p[keyPath: key] = value; draft.island.buildings[index] = p }
        })
    }
    private func mapCanvas(_ world: IslandSnapshot) -> some View {
        Canvas { context, size in
            let cell = zoom
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.48, green: 0.76, blue: 0.77)))
            for tx in 0..<112 { for ty in 0..<96 {
                let tile = world.terrain(tx * 96 + ty, edits: edits)
                let color = tileColor(tile, x: tx, y: ty, world: world)
                context.fill(Path(CGRect(x: Double(tx + 16) * cell, y: Double(ty + 16) * cell, width: cell + 0.1, height: cell + 0.1)), with: .color(color))
            } }
            if grid {
                var lines = Path()
                for i in 0...144 { lines.move(to: CGPoint(x: Double(i) * cell, y: 0)); lines.addLine(to: CGPoint(x: Double(i) * cell, y: 128 * cell)) }
                for i in 0...128 { lines.move(to: CGPoint(x: 0, y: Double(i) * cell)); lines.addLine(to: CGPoint(x: 144 * cell, y: Double(i) * cell)) }
                context.stroke(lines, with: .color(.black.opacity(0.08)), lineWidth: 0.5)
            }
            var acres = Path()
            for i in 0...9 { acres.move(to: CGPoint(x: Double(i * 16) * cell, y: 0)); acres.addLine(to: CGPoint(x: Double(i * 16) * cell, y: 128 * cell)) }
            for i in 0...8 { acres.move(to: CGPoint(x: 0, y: Double(i * 16) * cell)); acres.addLine(to: CGPoint(x: 144 * cell, y: Double(i * 16) * cell)) }
            context.stroke(acres, with: .color(.white.opacity(0.18)), lineWidth: 1)
            if showItems || layer == .items {
                // Resolve each artwork once per frame, even on densely planted islands.
                var artwork: [UInt16: GraphicsContext.ResolvedImage] = [:]
                let visibleLayers = layer == .items ? [itemLayer] : [0, 1]
                for visibleLayer in visibleLayers {
                    for index in 0..<IslandLayout.fieldCount {
                        let item = world.fieldItem(visibleLayer * IslandLayout.fieldCount + index, edits: edits)
                        // Extension cells belong to their root object and have no separate icon.
                        guard !item.isEmpty, item.id != 0xFFFD else { continue }
                        if artwork[item.id] == nil, let image = ItemIconStore.shared.image(for: item.id) {
                            artwork[item.id] = context.resolve(Image(nsImage: image))
                        }
                        guard let image = artwork[item.id] else { continue }
                        let px = Double(index / 192) / 2
                        let py = Double(index % 192) / 2 + 16
                        // Center on the same one-tile marker used by item selection.
                        let side = cell * 1.4
                        let aspect = image.size.width / max(1, image.size.height)
                        let width = side * min(1, aspect)
                        let height = side / max(1, aspect)
                        let rect = CGRect(x: (px + 0.5) * cell - width / 2,
                                          y: (py + 0.5) * cell - height / 2,
                                          width: width, height: height)
                        context.draw(image, in: rect)
                    }
                }
            }
            if showBuildings || layer == .buildings {
                let plazaRect = MapCoordinates.plazaBounds(world.plaza(edits: edits), zoom: cell)
                let plazaSelected = selectedBuilding == IslandLayout.plazaSelectionID && layer == .buildings
                context.fill(Path(plazaRect), with: .color(Color.brown.opacity(plazaSelected ? 0.28 : 0.14)))
                context.stroke(Path(plazaRect), with: .color(plazaSelected ? Color.island : .white.opacity(0.65)),
                               style: StrokeStyle(lineWidth: plazaSelected ? 2 : 1, dash: [4, 3]))
                context.draw(Text("Plaza").font(.system(size: 11, weight: .semibold)).foregroundColor(.primary),
                             at: CGPoint(x: plazaRect.midX, y: plazaRect.maxY - 8))
                for index in 0..<IslandLayout.buildingCount {
                    let building = world.building(index, edits: edits)
                    guard building.kind != 0 else { continue }
                    let point = MapCoordinates.buildingPoint(building.position, zoom: cell)
                    let rect = MapCoordinates.buildingBounds(building, zoom: cell)
                    let selected = index == selectedBuilding && layer == .buildings
                    let hasGuide = BuildingFootprint.forBuilding(building) != nil
                    if showBuildingGuides && hasGuide {
                        context.fill(Path(rect), with: .color(Color.brown.opacity(selected ? 0.22 : 0.10)))
                        context.stroke(Path(rect), with: .color(selected ? Color.island : .white.opacity(0.65)), lineWidth: selected ? 2 : 0.7)
                        if selected {
                            context.stroke(Path(rect.insetBy(dx: -cell, dy: -cell)),
                                with: .color(Color.island.opacity(0.8)), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        }
                    }
                    if let artwork = BuildingIconStore.shared.image(for: building.kind) {
                        let image = context.resolve(Image(nsImage: artwork))
                        let side = max(10, min(rect.width, rect.height))
                        var iconContext = context
                        iconContext.translateBy(x: point.x, y: point.y)
                        if building.kind == 26 || building.kind == 27 {
                            // Cardinal orientation plus the diagonal model's intrinsic turn.
                            let diagonal = BuildingFootprint.isDiagonalBridge(building) ? 45.0 : 0
                            iconContext.rotate(by: .degrees(Double(building.position.angle) * 90 + diagonal))
                        }
                        iconContext.draw(image, in: CGRect(x: -side / 2, y: -side / 2, width: side, height: side))
                    } else {
                        context.draw(Image(systemName: "building.2.fill"), at: CGPoint(x: point.x, y: point.y))
                    }
                    if selected {
                        context.stroke(Path(rect.insetBy(dx: -2, dy: -2)), with: .color(Color.island), lineWidth: 2)
                        // Always expose the original saved anchor independently of artwork.
                        context.fill(Path(ellipseIn: CGRect(x: point.x - 1.5, y: point.y - 1.5, width: 3, height: 3)), with: .color(.white))
                        context.draw(Text(building.name).font(.system(size: 11, weight: .semibold)).foregroundColor(.primary),
                                     at: CGPoint(x: point.x, y: rect.maxY + 10))
                    }
                }
            }
            if layer != .buildings {
                let selection: CGRect
                if layer == .items { selection = CGRect(x: Double(itemX) / 2 * cell, y: (Double(itemY) / 2 + 16) * cell, width: snapToGrid ? cell : cell / 2, height: snapToGrid ? cell : cell / 2) }
                else { selection = CGRect(x: Double(x + 16) * cell, y: Double(y + 16) * cell, width: cell, height: cell) }
                context.stroke(Path(selection.insetBy(dx: -1, dy: -1)), with: .color(.white), lineWidth: 3)
                context.stroke(Path(selection.insetBy(dx: -2, dy: -2)), with: .color(Color.island), lineWidth: 1)
            }
        }
        .contentShape(Rectangle())
        .focusable()
        .focused($mapFocused)
        .focusEffectDisabled()
        .onMoveCommand(perform: moveSelection)
        .onCopyCommand(perform: layer == .items ? copyProviders : nil)
        .onPasteCommand(of: layer == .items ? [Self.mapItemType] : [], perform: pasteProviders)
        .onDeleteCommand(perform: layer == .items ? { model.clearMapItem(at: selectedItemIndex) } : nil)
        .accessibilityLabel("Island map. Click to focus. Arrow keys select tiles; pinch to zoom. In Items, Command C copies, Command V pastes, and Delete removes the selected object.")
    }
    private func selectMapPoint(_ point: NSPoint, world: IslandSnapshot) {
        // The native hosting view converts pointer positions to the fixed logical
        // document. Drawing resolution changes independently of these coordinates.
        let cellSize = MapZoom.pointsPerTile
        if layer == .items {
            guard let cell = MapCoordinates.item(x: point.x, y: point.y, zoom: cellSize) else { return }
            selectItemCell(cell)
        } else if layer == .buildings {
            let buildings = (0..<IslandLayout.buildingCount).map { world.building($0, edits: edits) }
            if let nearest = MapCoordinates.buildingAt(x: point.x, y: point.y, zoom: cellSize, buildings: buildings) {
                selectedBuilding = nearest
            } else if MapCoordinates.plazaAt(x: point.x, y: point.y, zoom: cellSize, position: world.plaza(edits: edits)) {
                selectedBuilding = IslandLayout.plazaSelectionID
            }
        } else {
            guard let cell = MapCoordinates.terrain(x: point.x, y: point.y, zoom: cellSize) else {
                previousPoint = nil
                return
            }
            x = cell.x; y = cell.y
            if tool != .inspect { paint(to: (cell.x, cell.y), world: world) }
        }
    }
    private func paint(to point: (Int, Int), world: IslandSnapshot) {
        let start = previousPoint ?? point
        let steps = max(abs(point.0 - start.0), abs(point.1 - start.1), 1)
        let before = model.draft
        model.change(recordUndo: !strokeRecorded) { draft in
            for step in 0...steps {
                let px = start.0 + (point.0 - start.0) * step / steps
                let py = start.1 + (point.1 - start.1) * step / steps
                for dx in -(brushSize / 2)...(brushSize / 2) { for dy in -(brushSize / 2)...(brushSize / 2) {
                    guard let index = try? IslandLayout.terrainIndex(x: px + dx, y: py + dy) else { continue }
                    var tile = world.terrain(index, edits: draft.island)
                    if tool == .ground { tile.ground = ground; tile.angle = angle; tile.variation = 0; tile.elevation = elevation }
                    else { tile.path = path; tile.pathAngle = angle; tile.pathVariation = 0 }
                    draft.island.terrain[index] = tile
                } }
            }
        }
        if model.draft != before { strokeRecorded = true }
        previousPoint = point
    }
    private func tileColor(_ tile: TerrainTile, x: Int, y: Int, world: IslandSnapshot) -> Color {
        let acre = Int(world.main.u16(IslandLayout.acres + ((y / 16 + 1) * 9 + (x / 16 + 1)) * 2))
        if acre != 0 {
            let offset = acre * 4096 + 4 * ((y % 16) * 64 + x % 16)
            if offset < Self.acres.count {
                let type = Self.acres[offset]
                if type != 7 {
                    let colors: [UInt8: (Double, Double, Double)] = [0: (70,120,64), 1: (128,215,195), 3: (192,192,192), 4: (240,230,170), 5: (128,215,195), 6: (255,128,128), 29: (232,222,162), 41: (118,122,132), 42: (128,133,147), 44: (62,112,56), 45: (118,122,132), 46: (120,207,187), 49: (190,98,98)]
                    if let c = colors[type] { return Color(red: c.0 / 255, green: c.1 / 255, blue: c.2 / 255) }
                }
            }
        }
        if tile.path != 0 {
            switch pathBase(tile.path) {
            case 0x47: return Color(red: 0.68, green: 0.48, blue: 0.30)
            case 0x94: return Color(red: 0.67, green: 0.32, blue: 0.26)
            case 0xA9: return Color(red: 0.42, green: 0.30, blue: 0.20)
            case 0xBE: return .init(red: 0.80, green: 0.80, blue: 0.71)
            case 0xD3: return .init(red: 0.91, green: 0.84, blue: 0.61)
            case 0xE8: return .init(red: 0.52, green: 0.65, blue: 0.72)
            case 0xFD: return .init(red: 0.67, green: 0.53, blue: 0.37)
            default: return .init(red: 0.68, green: 0.69, blue: 0.66)
            }
        }
        if tile.isWater { return .init(red: 0.50, green: 0.84, blue: 0.77) }
        let level = Double(min(tile.elevation, 3))
        return .init(red: 0.30 + level * 0.10, green: 0.55 + level * 0.08, blue: 0.31 + level * 0.07)
    }
}
