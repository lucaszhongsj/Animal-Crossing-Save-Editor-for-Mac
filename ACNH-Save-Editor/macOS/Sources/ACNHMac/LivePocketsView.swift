import SwiftUI
import ACNHCore

struct LivePocketsView: View {
    @EnvironmentObject var model: EditorModel

    var body: some View {
        if model.livePockets != nil {
            PocketInventoryView(live: true)
        } else {
            VStack(spacing: 14) {
                Image(systemName: "gamecontroller").font(.largeTitle).foregroundStyle(Color.island)
                Text("Live Pockets").font(.title2.bold())
                Text("Load your island as the primary resident and save in-game, then connect. macOS may ask you to authorize access to the running game.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
                Button("Connect to Live Game", action: model.connectLivePockets).buttonStyle(.borderedProminent)
                Text("Requires Animal Crossing 3.0.3 running in nxnative on an Apple silicon Mac.")
                    .font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: 420).padding(26).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

extension EditorModel {
    func connectLivePockets() {
        perform("Looking for live pockets…", operation: LivePocketConnection.connect) { connection, slots in
            self.livePocketHistory.removeAll()
            self.liveConnection = connection
            self.livePockets = slots
            self.status = "Connected to the live game."
        }
    }

    func refreshLivePockets(automatic: Bool = false) {
        guard let liveConnection else { return }
        perform("Reading live pockets…", reportError: !automatic, operation: liveConnection.refresh) { slots in
            self.livePockets = slots
            self.livePocketSelection.retain(Array(slots.indices))
            self.status = "Live pockets refreshed."
        }
    }

    func disconnectLivePockets() {
        livePocketHistory.removeAll()
        liveConnection = nil
        livePockets = nil
        livePocketSelection = InventorySelection()
        status = "Disconnected from the live game."
    }

    func sendLivePocketItem() {
        guard let item = currentItem else { return }
        do {
            let record = try PocketItem.make(id: item.id, quantity: quantity, maxStack: item.maxStack)
            editLivePockets(record, slots: livePocketSelection.indices, action: "Sent \(item.name) to")
        } catch { self.error = error.localizedDescription }
    }

    func editLivePockets(_ item: PocketItem, slots: Set<Int>, action: String) {
        guard let liveConnection, let current = livePockets, !slots.isEmpty,
              slots.allSatisfy(current.indices.contains) else { return }
        let changed = slots.filter { current[$0] != item }
        guard !changed.isEmpty else { return }
        let before = Dictionary(uniqueKeysWithValues: changed.map { ($0, current[$0]) })
        let after = Dictionary(uniqueKeysWithValues: changed.map { ($0, item) })
        perform("Updating live pockets…", operation: {
            try liveConnection.apply(after, expected: before)
        }) { updated in
            self.livePockets = updated
            self.livePocketHistory.append((before, after))
            if self.livePocketHistory.count > 150 { self.livePocketHistory.removeFirst() }
            self.status = "\(action) \(changed.count) pocket slot(s). Reopen your pockets to see the changes. Save in-game to keep them."
        }
    }

    func undoLivePocketEdit() {
        guard let liveConnection, let edit = livePocketHistory.last else { return }
        perform("Undoing live pocket edit…", operation: {
            try liveConnection.apply(edit.before, expected: edit.after)
        }) { updated in
            self.livePockets = updated
            self.livePocketHistory.removeLast()
            self.status = "Last live pocket edit undone. Reopen your pockets to see the changes. Save in-game to keep them."
        }
    }

    func updatePocketQuantity(_ index: Int, quantity: Int, live: Bool) {
        let items = live ? livePockets : draft?.pockets
        guard let items, items.indices.contains(index), let item = catalog.byID[items[index].id] else { return }
        do {
            let record = try items[index].changingQuantity(to: quantity, maxStack: item.maxStack)
            if live { editLivePockets(record, slots: [index], action: "Updated quantity in") }
            else {
                change { $0.pockets[index] = record }
                status = "Quantity updated in pocket \(index + 1)."
            }
        } catch { self.error = error.localizedDescription }
    }
}
