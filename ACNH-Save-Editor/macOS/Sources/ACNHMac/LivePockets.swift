import Foundation
import Darwin
import ACNHCore

struct LivePocketLayout {
    static let block = 160
    static let upper = SaveLayout.pocketBase - SaveLayout.extraPocketBase
    static let span = upper + block + 4

    let first: Int
    let extra: Int

    init(_ bytes: Data) throws {
        first = Int(bytes.u32(Self.upper + Self.block))
        extra = Int(bytes.u32(Self.block))
        guard (1...20).contains(first), (0...20).contains(extra) else {
            throw SaveError("The game returned an unsupported pocket capacity.")
        }
    }

    var offsets: [Int] {
        (0..<first).map { Self.upper + $0 * 8 } + (0..<extra).map { $0 * 8 }
    }

    func records(_ bytes: Data) -> [PocketItem] {
        offsets.map { PocketItem(raw: bytes.subdata(in: $0..<($0 + 8))) }
    }

    static func sameInventory(_ lhs: Data, _ rhs: Data) -> Bool {
        lhs.prefix(block + 4) == rhs.prefix(block + 4) &&
        lhs.suffix(block + 4) == rhs.suffix(block + 4)
    }

    func resemblesSave(_ live: Data, baseline: Data) -> Bool {
        if Self.sameInventory(live, baseline) { return true }
        let saved = records(baseline)
        let current = records(live)
        let unchanged = saved.indices.filter { saved[$0] == current[$0] }
        return saved.count - unchanged.count <= 4 &&
            unchanged.filter { !saved[$0].isEmpty }.count >= 3
    }

    static func uniqueLivePair(in candidates: [UInt64]) -> [UInt64]? {
        // ACNH 3.0.3 places the two live resident records one personal record
        // plus 0x20 bytes apart. The saved snapshot is elsewhere in the heap.
        let stride = UInt64(SaveLayout.personalSize + 0x20)
        let addresses = Set(candidates)
        let starts = addresses.filter { $0 <= UInt64.max - stride && addresses.contains($0 + stride) }
        guard starts.count == 1, let first = starts.first else { return nil }
        return [first, first + stride]
    }
}

final class LivePocketConnection {
    private static let title = "01006F8002326000"
    private let memory: LivePocketMemory
    private let layout: LivePocketLayout
    private let live: [UInt64]

    private init(memory: LivePocketMemory, layout: LivePocketLayout, live: [UInt64]) {
        self.memory = memory
        self.layout = layout
        self.live = live
    }

    static func connect() throws -> (LivePocketConnection, [PocketItem]) {
        let ps = Process()
        let pipe = Pipe()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = ["-axo", "pid=,comm="]
        ps.standardOutput = pipe
        try ps.run()
        let processes = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        ps.waitUntilExit()
        let hosts: [(Int32, URL)] = processes.split(separator: "\n").compactMap { line in
            let fields = line.split(maxSplits: 1, whereSeparator: \.isWhitespace)
            guard fields.count == 2, let pid = Int32(fields[0]), fields[1].hasSuffix(".app/Contents/MacOS/dmhost") else { return nil }
            let app = URL(fileURLWithPath: String(fields[1])).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            guard Bundle(url: app)?.object(forInfoDictionaryKey: "DMTitleID") as? String == title else { return nil }
            return (pid, app)
        }
        guard hosts.count == 1, let (pid, app) = hosts.first else {
            throw SaveError("Open exactly one nxnative Animal Crossing app and load your island, then try connecting again.")
        }
        guard Bundle(url: app)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == "3.0.3" else {
            throw SaveError("Live Pockets currently supports Animal Crossing 3.0.3.")
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let name = "\(title).log"
        let logs = [
            app.deletingLastPathComponent().appendingPathComponent("log/\(name)"),
            home.appendingPathComponent("Library/Logs/nxnative/\(name)")
        ]
        let hostPath = app.appendingPathComponent("Contents/MacOS/dmhost").path
        let logsByDate = logs.compactMap { url -> (URL, Date)? in
            guard let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else { return nil }
            return (url, date)
        }.sorted { $0.1 > $1.1 }
        guard let log = logsByDate.lazy.compactMap({ try? String(contentsOf: $0.0, encoding: .utf8) })
            .first(where: { $0.split(separator: "\n").contains { $0.hasPrefix("launcher:") && $0.hasSuffix("host \(hostPath)") } }),
              let range = heapRange(in: log),
              let mount = log.split(separator: "\n").last(where: { $0.contains("fs mount deviceSave:") }),
              let path = mount.range(of: "→ "),
              let end = mount.range(of: " (transactional save:", range: path.upperBound..<mount.endIndex) else {
            throw SaveError("Couldn’t find this game’s memory layout and save folder in the nxnative log. Load your island first.")
        }
        let workPath = String(mount[path.upperBound..<end.lowerBound])
        guard workPath.hasPrefix("/"), workPath.hasSuffix(".work") else {
            throw SaveError("Couldn’t identify the game’s committed save folder.")
        }
        let save = URL(fileURLWithPath: String(workPath.dropLast(5))).appendingPathComponent("Villager0")
        let header = try Data(contentsOf: save.appendingPathComponent("personalHeader.dat"))
        let encrypted = try Data(contentsOf: save.appendingPathComponent("personal.dat"))
        guard encrypted.count == SaveLayout.personalSize, try SaveLayout.version(header) == "3.0.3" else {
            throw SaveError("Live Pockets requires a saved 3.0.3 island with the primary resident loaded.")
        }
        let personal = try SaveCodec.crypt(encrypted, header: header)
        try SaveLayout.verify(personal, regions: SaveLayout.personalRegions, name: "personal.dat")
        let base = SaveLayout.extraPocketBase
        let baseline = personal.subdata(in: base..<(base + LivePocketLayout.span))
        let layout = try LivePocketLayout(baseline)
        let memory = try LivePocketMemory(pid: pid)
        let candidates = try memory.search(range, for: baseline)
        guard let pair = LivePocketLayout.uniqueLivePair(in: candidates) else {
            throw SaveError("Couldn’t identify a unique live pocket pair. Save in-game as the primary resident and reconnect. If this continues, Live Pockets is unavailable on this build.")
        }
        let connection = LivePocketConnection(memory: memory, layout: layout, live: pair)
        let copies = try connection.snapshots()
        guard layout.resemblesSave(copies[0], baseline: baseline) else {
            throw SaveError("Your pockets changed while connecting. Save in-game, then reconnect.")
        }
        return (connection, layout.records(copies[0]))
    }

    static func heapRange(in log: String) -> Range<UInt64>? {
        let marker = "guest AS "
        guard let line = log.split(separator: "\n").last(where: { $0.contains(marker) }),
              let prefix = line.range(of: marker) else { return nil }
        let fields = line[prefix.upperBound...].split(separator: " ")
        guard fields.count >= 4, fields[2] == "heap",
              let start = UInt64(fields[0].dropFirst(2), radix: 16),
              let size = UInt64(fields[1].dropFirst(3), radix: 16),
              let heap = UInt64(fields[3].dropFirst(2), radix: 16),
              size <= 0x20_0000_0000, start <= UInt64.max - size,
              heap >= start, heap < start + size else { return nil }
        return heap..<(start + size)
    }

    private func hasSameCapacity(_ bytes: Data) throws -> Bool {
        let current = try LivePocketLayout(bytes)
        return current.first == layout.first && current.extra == layout.extra
    }

    private func snapshots() throws -> [Data] {
        let copies = try live.map { try memory.read($0, count: LivePocketLayout.span) }
        guard try hasSameCapacity(copies[0]), LivePocketLayout.sameInventory(copies[0], copies[1]) else {
            throw SaveError("The two live pocket copies disagree. Close your pockets, then refresh or reconnect.")
        }
        return copies
    }

    func refresh() throws -> [PocketItem] {
        layout.records(try snapshots()[0])
    }

    func apply(_ replacements: [Int: PocketItem], expected: [Int: PocketItem]) throws -> [PocketItem] {
        let before = try snapshots()
        let offsets = layout.offsets
        let records = layout.records(before[0])
        guard !replacements.isEmpty, replacements.keys.allSatisfy({ index in
            offsets.indices.contains(index) && records[index] == expected[index] && replacements[index]?.raw.count == 8
        }) else {
            throw SaveError("The affected pockets changed in-game. Refresh and check those slots before trying again.")
        }
        let changed = replacements.keys.sorted().filter { records[$0] != replacements[$0] }
        var attempted: [(address: UInt64, original: Data, replacement: Data)] = []
        do {
            for i in live.indices {
                guard LivePocketLayout.sameInventory(try memory.read(live[i], count: LivePocketLayout.span), before[i]) else {
                    throw SaveError("Your pockets changed while applying the edit. Refresh and try again.")
                }
                for index in changed {
                    let offset = offsets[index]
                    let address = live[i] + UInt64(offset)
                    let original = records[index].raw
                    let replacement = replacements[index]!.raw
                    guard try memory.read(address, count: 8) == original else {
                        throw SaveError("A pocket changed while applying the edit. Refresh and try again.")
                    }
                    attempted.append((address, original, replacement))
                    try memory.write(replacement, at: address)
                }
            }
            let actual = try refresh()
            guard replacements.allSatisfy({ actual[$0.key] == $0.value }) else { throw SaveError("The live pocket write could not be verified.") }
            return actual
        } catch {
            var restored = true
            for (address, original, replacement) in attempted.reversed() {
                do {
                    let current = try memory.read(address, count: 8)
                    if current == replacement { try memory.write(original, at: address) }
                    if try memory.read(address, count: 8) != original { restored = false }
                } catch {
                    restored = false
                }
            }
            guard restored else {
                throw SaveError("Couldn’t restore a pocket after a write error. Check your pockets in-game before saving.")
            }
            throw error
        }
    }
}

private final class LivePocketMemory {
    private let task: mach_port_t

    init(pid: Int32) throws {
        var port: mach_port_t = 0
        guard task_for_pid(mach_task_self_, pid, &port) == KERN_SUCCESS else {
            throw SaveError("macOS didn’t grant access to the game. Approve the macOS developer tools prompt when connecting and keep the game running.")
        }
        task = port
    }

    deinit { mach_port_deallocate(mach_task_self_, task) }

    func read(_ address: UInt64, count: Int) throws -> Data {
        var data = Data(count: count)
        var copied: mach_vm_size_t = 0
        let result = data.withUnsafeMutableBytes { buffer in
            mach_vm_read_overwrite(task, address, UInt64(count), UInt64(UInt(bitPattern: buffer.baseAddress)), &copied)
        }
        guard result == KERN_SUCCESS, copied == count else {
            throw SaveError("Couldn’t read the running game. If it was closed or relaunched, disconnect and reconnect.")
        }
        return data
    }

    func write(_ data: Data, at address: UInt64) throws {
        let result = data.withUnsafeBytes { buffer in
            mach_vm_write(task, address, UInt(bitPattern: buffer.baseAddress), UInt32(data.count))
        }
        guard result == KERN_SUCCESS else { throw SaveError("macOS couldn’t write to the running game.") }
    }

    func search(_ range: Range<UInt64>, for baseline: Data) throws -> [UInt64] {
        let chunk = 8 * 1024 * 1024
        let blockSize = LivePocketLayout.block + 4
        let needles = [0, LivePocketLayout.upper].map { offset in
            (offset, baseline.subdata(in: offset..<(offset + blockSize)))
        }
        var cursor = range.lowerBound
        var matches = Set<UInt64>()
        while cursor < range.upperBound {
            var start = cursor
            var size: mach_vm_size_t = 0
            var info = vm_region_basic_info_data_64_t()
            var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.size)
            var object: mach_port_t = 0
            let result = withUnsafeMutablePointer(to: &info) { pointer in
                pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    mach_vm_region(task, &start, &size, VM_REGION_BASIC_INFO_64, $0, &count, &object)
                }
            }
            if object != 0 { mach_port_deallocate(mach_task_self_, object) }
            if result == KERN_INVALID_ADDRESS || start >= range.upperBound { break }
            guard result == KERN_SUCCESS, start + size > cursor else { throw SaveError("Couldn’t inspect the game’s memory regions.") }
            let end = min(start + size, range.upperBound)
            start = max(start, cursor)
            cursor = end
            guard info.protection & (VM_PROT_READ | VM_PROT_WRITE) == (VM_PROT_READ | VM_PROT_WRITE) else { continue }
            while start < end {
                let step = min(chunk, Int(end - start))
                let size = min(step + LivePocketLayout.span - 1, Int(end - start))
                let bytes = try read(start, count: size)
                for (blockOffset, needle) in needles {
                    var offset = 0
                    while offset + blockSize <= bytes.count,
                          let match = bytes.range(of: needle, in: offset..<bytes.count),
                          match.lowerBound < step {
                        let address = start + UInt64(match.lowerBound)
                        if address >= range.lowerBound + UInt64(blockOffset), address.isMultiple(of: 8) {
                            matches.insert(address - UInt64(blockOffset))
                            guard matches.count <= 128 else {
                                throw SaveError("Too many matching pocket copies. Put a few items in your pockets, save, and reconnect.")
                            }
                        }
                        offset = match.lowerBound + 1
                    }
                }
                start += UInt64(step)
            }
        }
        return Array(matches)
    }
}
