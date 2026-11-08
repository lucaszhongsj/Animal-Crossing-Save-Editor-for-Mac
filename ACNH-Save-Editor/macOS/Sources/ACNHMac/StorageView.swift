import SwiftUI
import ACNHCore

struct StorageView: View {
    @EnvironmentObject var model: EditorModel
    @State private var query = ""
    @State private var occupiedOnly = false
    @State private var page = 0
    private let pageSize = 50
    private var items: [PocketItem] { model.draft?.storage ?? [] }
    private var matches: [Int] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex = q.lowercased().hasPrefix("0x") ? String(q.dropFirst(2)) : q
        return items.indices.filter { index in
            let item = items[index]
            return (!occupiedOnly || !item.isEmpty) && (q.isEmpty || model.catalog.name(item, emptyLabel: "Empty slot").localizedCaseInsensitiveContains(q) || String(format: "%04X", item.id).caseInsensitiveCompare(hex) == .orderedSame)
        }
    }
    private var pageCount: Int { max(1, (matches.count + pageSize - 1) / pageSize) }
    private var visible: [Int] { Array(matches.dropFirst(min(page, pageCount - 1) * pageSize).prefix(pageSize)) }
    var body: some View {
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Room for your favorites.").font(.system(size: 28, weight: .semibold, design: .rounded))
                        Text("\(items.filter { !$0.isEmpty }.count.formatted()) items stored · \(items.count.formatted()) unlocked slots").foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    if model.demo {
                        Label("Preview · Example storage. Open your save to export or save edits.", systemImage: "eye").font(.callout).foregroundStyle(Color.island)
                    }
                    if items.isEmpty {
                        ContentUnavailableView("Home Storage Is Locked", systemImage: "archivebox", description: Text("This resident has no unlocked home storage. Upgrade their home in the game, then reopen a fresh save export."))
                    } else {
                        TextField("Search stored items or hex ID", text: Binding(get: { query }, set: { query = $0; page = 0; reconcileSelection() })).textFieldStyle(.roundedBorder).accessibilityLabel("Search stored items")
                        HStack {
                            Toggle("Occupied slots only", isOn: Binding(get: { occupiedOnly }, set: { occupiedOnly = $0; page = 0; reconcileSelection() })).toggleStyle(.checkbox)
                            Spacer()
                            Button("Find Empty Slot", action: findEmpty).disabled(!items.contains(where: \.isEmpty))
                        }
                        HStack {
                            Text("\(matches.count.formatted()) matching slots").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button { page = 0 } label: { Image(systemName: "backward.end") }.accessibilityLabel("First storage page").disabled(page == 0)
                            Button { page = max(0, page - 1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Previous storage page").disabled(page == 0)
                            Text("Page \(min(page, pageCount - 1) + 1) of \(pageCount)").font(.caption.monospacedDigit())
                            Button { page = min(pageCount - 1, page + 1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Next storage page").disabled(page >= pageCount - 1)
                            Button { page = pageCount - 1 } label: { Image(systemName: "forward.end") }.accessibilityLabel("Last storage page").disabled(page >= pageCount - 1)
                        }
                        InventorySelectionHint(selection: model.storageSelection, paged: true)
                        if matches.isEmpty {
                            ContentUnavailableView("No Matching Items", systemImage: "magnifyingglass", description: Text("Change the search or turn off Occupied slots only to see empty slots."))
                        } else {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                                ForEach(visible, id: \.self) { index in storageCell(index) }
                            }
                        }
                        Text("Edits apply to the primary resident’s home storage. Locked slots, storage upgrades, and other residents are preserved.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Button("Revert Storage Changes") {
                            guard let initial = model.session?.initial else { return }
                            model.change { $0.storage = initial.storage }
                        }.disabled(model.session == nil || model.draft?.storage == model.session?.initial.storage)
                    }
                }.padding(26)
            }.safeAreaInset(edge: .bottom, spacing: 0) {
                if let index = model.storageSelection.single, items.indices.contains(index), visible.contains(index) {
                    VStack(spacing: 0) {
                        Divider()
                        InventorySlotInspector(title: "Storage slot \(index + 1)", item: items[index],
                                               remove: { model.clearStorageSlot(index) },
                                               updateQuantity: { model.updateStorageQuantity(index, quantity: $0) }).id(index).padding(.horizontal, 26).padding(.vertical, 12)
                    }.background(Color(nsColor: .windowBackgroundColor))
                } else if model.storageSelection.indices.count > 1 {
                    HStack {
                        Text("\(model.storageSelection.indices.count) storage slots selected").font(.headline)
                        Spacer()
                        Button("Clear Selected Slots") { model.clearSelected(in: .storage) }
                            .disabled(!model.storageSelection.indices.contains { items[$0].isEmpty == false })
                    }.padding(20).background(Color(nsColor: .windowBackgroundColor))
                }
            }.frame(minWidth: 460, idealWidth: 650)
            ItemLibraryView(destination: .storage).frame(minWidth: 290, idealWidth: 330, maxWidth: 430)
        }
        .onChange(of: page) { reconcileSelection() }
        .onChange(of: matches) { page = min(page, pageCount - 1); reconcileSelection() }
        .onAppear {
            if let index = model.storageSelection.indices.min(), let position = matches.firstIndex(of: index) { page = position / pageSize }
            reconcileSelection()
        }
    }
    private func reconcileSelection() {
        model.storageSelection.retain(visible)
    }
    private func findEmpty() {
        guard let index = items.firstIndex(where: \.isEmpty) else { return }
        query = ""; occupiedOnly = false; page = index / pageSize
        model.storageSelection.replace(with: [index])
    }
    private func storageCell(_ index: Int) -> some View {
        let item = items[index], selected = model.storageSelection.indices.contains(index)
        return Button {
            let flags = NSApp.currentEvent?.modifierFlags ?? NSEvent.modifierFlags
            model.storageSelection.click(index, visible: visible, command: flags.contains(.command), shift: flags.contains(.shift))
        } label: {
            VStack(spacing: 7) {
                HStack {
                    Text("\(index + 1)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    if selected { Image(systemName: "checkmark.circle.fill").font(.caption2).foregroundStyle(Color.island) }
                    Spacer()
                    Text(model.catalog.quantity(item)).font(.caption2.weight(.semibold)).foregroundStyle(Color.island)
                }
                ItemIcon(id: item.id, size: 40)
                Text(model.catalog.name(item, emptyLabel: "Empty slot")).font(.system(size: 10, weight: .medium)).lineLimit(2).multilineTextAlignment(.center).frame(height: 28)
            }.padding(9).frame(maxWidth: .infinity, minHeight: 94)
                .background(selected ? Color.island.opacity(0.1) : Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Color.island : Color.primary.opacity(0.08), lineWidth: selected ? 2 : 1))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : []).accessibilityLabel("Storage slot \(index + 1), \(model.catalog.name(item, emptyLabel: "Empty slot")) \(model.catalog.quantity(item))")
    }
}

struct InventorySlotInspector: View {
    @EnvironmentObject var model: EditorModel
    let title: String
    let item: PocketItem
    let remove: () -> Void
    let updateQuantity: (Int) -> Void
    @State private var quantity = 1
    private var stackLimit: Int { model.catalog.byID[item.id]?.maxStack ?? 1 }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ItemIcon(id: item.id, size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.caption).foregroundStyle(.secondary)
                    Text(model.catalog.name(item, emptyLabel: "Empty slot")).font(.headline)
                    if !item.isEmpty { Text(String(format: "Item %04X", item.id)).font(.caption.monospaced()).foregroundStyle(.secondary) }
                }
                Spacer()
                Button("Remove Item", action: remove).disabled(item.isEmpty)
            }
            if !item.isEmpty && stackLimit > 1 {
                HStack {
                    Stepper("Stored quantity: \(quantity)", value: $quantity, in: 1...stackLimit)
                    Spacer()
                    Button("Update Quantity") { updateQuantity(quantity) }.disabled(quantity == item.storedCount + 1)
                }
                Text("Quantity changes preserve this item’s other details.").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(16).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
            .onAppear { loadQuantity() }.onChange(of: item) { loadQuantity() }
    }
    private func loadQuantity() { quantity = max(1, min(stackLimit, item.storedCount + 1)) }
}
