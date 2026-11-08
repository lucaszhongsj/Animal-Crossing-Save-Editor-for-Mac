import SwiftUI
import AppKit
import ACNHCore

struct PocketInventoryView: View {
    @EnvironmentObject var model: EditorModel
    @State private var query = ""
    @State private var occupiedOnly = false
    let live: Bool

    private var items: [PocketItem] { (live ? model.livePockets : model.draft?.pockets) ?? [] }
    private var selection: Binding<InventorySelection> { live ? $model.livePocketSelection : $model.pocketSelection }
    private var visible: [Int] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex = search.lowercased().hasPrefix("0x") ? String(search.dropFirst(2)) : search
        return items.indices.filter { index in
            let item = items[index]
            return (!occupiedOnly || !item.isEmpty) && (search.isEmpty ||
                model.catalog.name(item).localizedCaseInsensitiveContains(search) ||
                String(format: "%04X", item.id).caseInsensitiveCompare(hex) == .orderedSame)
        }
    }

    var body: some View {
        HSplitView {
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Text(live ? "Live Pockets" : "Pockets, packed your way.")
                                .font(.system(size: 28, weight: .semibold, design: .rounded))
                            Spacer()
                            Button("Undo Edit") {
                                if live { model.undoLivePocketEdit() }
                                else { model.undoPocketEdit() }
                            }
                            .disabled(live ? model.livePocketHistory.isEmpty : !model.canUndoPocketEdit)
                            .help("Undo the last pocket edit")
                            if live {
                                Button("Refresh") { model.refreshLivePockets() }
                                Button("Disconnect", action: model.disconnectLivePockets)
                            }
                        }
                        Text("\(items.filter { !$0.isEmpty }.count) items held · \(items.count) unlocked pockets")
                            .foregroundStyle(.secondary)
                        if live {
                            Text("Close and reopen your in-game pockets to see changes. Save in-game to keep them.")
                                .font(.caption).foregroundStyle(.secondary)
                        } else if model.demo {
                            Label("Preview · Example pockets. Open your save to export or save edits.", systemImage: "eye")
                                .foregroundStyle(Color.island)
                        }
                        TextField("Search pocket items or hex ID", text: $query).textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Search pocket items")
                        HStack {
                            Toggle("Occupied slots only", isOn: $occupiedOnly).toggleStyle(.checkbox)
                            Spacer()
                            Button("Find Empty Slot") {
                                guard let index = items.firstIndex(where: \.isEmpty) else { return }
                                query = ""
                                occupiedOnly = false
                                selection.wrappedValue.replace(with: [index])
                                Task { @MainActor in scroll.scrollTo(index, anchor: .center) }
                            }.disabled(!items.contains(where: \.isEmpty))
                        }
                        Text("\(visible.count) matching pockets").font(.caption).foregroundStyle(.secondary)
                        InventorySelectionHint(selection: selection.wrappedValue)
                        if visible.isEmpty {
                            ContentUnavailableView("No Matching Items", systemImage: "magnifyingglass",
                                                   description: Text("Change the search or turn off Occupied slots only to see empty pockets."))
                        } else {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                                ForEach(visible, id: \.self) { index in
                                    PocketCell(index: index, slot: items[index], selected: selection.wrappedValue.indices.contains(index)) {
                                        let flags = NSApp.currentEvent?.modifierFlags ?? NSEvent.modifierFlags
                                        selection.wrappedValue.click(index, visible: visible, command: flags.contains(.command), shift: flags.contains(.shift))
                                    }.id(index)
                                }
                            }
                        }
                        if !live {
                            Text("Edits apply to the primary resident’s unlocked pockets.").font(.caption).foregroundStyle(.secondary)
                            Button("Revert Pocket Changes") {
                                guard let initial = model.session?.initial else { return }
                                model.change { $0.pockets = initial.pockets }
                            }.disabled(model.session == nil || items == model.session?.initial.pockets)
                        }
                    }.padding(26)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { inspector }
            .frame(minWidth: 460, idealWidth: 650)
            ItemLibraryView(destination: live ? .livePocket : .pocket)
                .frame(minWidth: 290, idealWidth: 330, maxWidth: 430)
        }
        .onAppear { selection.wrappedValue.retain(visible) }
        .onChange(of: visible) { selection.wrappedValue.retain(visible) }
    }

    @ViewBuilder private var inspector: some View {
        let selected = selection.wrappedValue.indices.intersection(visible)
        if !selected.isEmpty {
            VStack(spacing: 0) {
                Divider()
                if let index = selected.first, selected.count == 1 {
                    InventorySlotInspector(title: "Pocket \(index + 1)", item: items[index],
                                           remove: clearSelection,
                                           updateQuantity: { model.updatePocketQuantity(index, quantity: $0, live: live) })
                        .id(index).padding(.horizontal, 26).padding(.vertical, 12)
                } else {
                    HStack {
                        Text("\(selected.count) pockets selected").font(.headline)
                        Spacer()
                        Button("Clear Selected Pockets", action: clearSelection)
                            .disabled(!selected.contains { !items[$0].isEmpty })
                    }.padding(20)
                }
            }.background(Color(nsColor: .windowBackgroundColor))
        }
    }

    private func clearSelection() {
        if live { model.editLivePockets(.empty, slots: selection.wrappedValue.indices, action: "Cleared") }
        else { model.clearSelected(in: .pockets) }
    }
}
