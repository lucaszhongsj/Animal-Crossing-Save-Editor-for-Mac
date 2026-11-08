import SwiftUI
import ACNHCore

struct ItemLibraryView: View {
    enum Destination { case pocket, livePocket, storage }
    @EnvironmentObject var model: EditorModel
    let destination: Destination
    private var selected: Set<Int> {
        switch destination {
        case .pocket: model.pocketSelection.indices
        case .livePocket: model.livePocketSelection.indices
        case .storage: model.storageSelection.indices
        }
    }
    private var records: [PocketItem] {
        switch destination {
        case .pocket: model.draft?.pockets ?? []
        case .livePocket: model.livePockets ?? []
        case .storage: model.draft?.storage ?? []
        }
    }
    private var canPlace: Bool { !selected.isEmpty && selected.allSatisfy { records.indices.contains($0) } }
    private var replacingCount: Int { selected.filter { records.indices.contains($0) && !records[$0].isEmpty }.count }
    private var placementTitle: String {
        if destination == .livePocket {
            return canPlace ? "Send to Game" : "Choose Pockets"
        }
        let name = destination == .pocket ? "Pocket" : "Storage Slot"
        guard canPlace else { return "Choose \(destination == .pocket ? "Pockets" : "Storage Slots")" }
        if selected.count == 1 { return "Place in \(name) \(selected.first! + 1)" }
        return "Place in \(selected.count) \(destination == .pocket ? "Pockets" : "Storage Slots")"
    }
    private func placeItem() {
        switch destination {
        case .pocket: model.placeItem()
        case .livePocket: model.sendLivePocketItem()
        case .storage: model.placeStorageItem()
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Item Library").font(.headline).padding(.top, 24)
            TextField("Search items or hex ID", text: $model.search).textFieldStyle(.roundedBorder)
                .accessibilityLabel("Search item library")
            Picker("Items", selection: $model.favoritesOnly) { Text("All Items").tag(false); Text("Favorites").tag(true) }.pickerStyle(.segmented)
            Text("\(model.filteredItems.count.formatted()) items").font(.caption).foregroundStyle(.secondary)
            List(selection: Binding(get: { model.selectedItem }, set: { if let id = $0 { model.selectItem(id) } })) {
                ForEach(model.filteredItems) { item in
                    HStack(spacing: 10) {
                        ItemIcon(id: item.id)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name).font(.callout).lineLimit(2)
                            Text(item.hex).font(.caption2.monospaced()).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        if Catalog.favoriteNames.contains(item.name) { Image(systemName: "star.fill").font(.caption2).foregroundStyle(.orange) }
                    }.padding(.vertical, 3).tag(item.id)
                }
            }.listStyle(.bordered(alternatesRowBackgrounds: true))
                .overlay { if model.filteredItems.isEmpty { ContentUnavailableView.search(text: model.search) } }
            if let item = model.currentItem {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        ItemIcon(id: item.id, size: 44)
                        Text(item.name).font(.headline).lineLimit(2)
                    }
                    Stepper("Quantity: \(model.quantity)", value: $model.quantity, in: 1...max(1, item.maxStack)).font(.callout)
                    Text("\(selected.count > 1 ? "Quantity per slot · " : "")Stack limit: \(item.maxStack)").font(.caption).foregroundStyle(.secondary)
                    if canPlace {
                        Text("\(selected.count) selected · \(replacingCount) occupied slot(s) will be replaced.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Button(placementTitle, action: placeItem)
                        .buttonStyle(.borderedProminent).frame(maxWidth: .infinity).disabled(!canPlace)
                }.padding(.vertical, 4)
            } else { Text("Select an item to choose its quantity and place it in the selected slots.").font(.caption).foregroundStyle(.secondary).padding(.vertical, 8) }
        }.padding(.horizontal, 18).padding(.bottom, 18)
    }
}
