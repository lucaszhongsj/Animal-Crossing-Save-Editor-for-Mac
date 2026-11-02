// Adapted from NHSE.Core BridgeType and BridgeMaterial, GPL-3.0.
// Reference revision cb0745415945776f73375bf0a434a8babf059307.
import Foundation

public enum BridgeStyle: UInt8, CaseIterable, Identifiable {
    case stone = 0, suspension = 1, zen = 2, log = 4, redZen = 5
    case iron = 6, reserved = 7, wooden = 10, brick = 11
    public var id: UInt8 { rawValue }
    public var name: String {
        switch self {
        case .stone: return "Stone"
        case .suspension: return "Suspension"
        case .zen: return "Zen"
        case .log: return "Log"
        case .redZen: return "Red zen"
        case .iron: return "Iron"
        case .reserved: return "Reserved (NHSE)"
        case .wooden: return "Wooden"
        case .brick: return "Brick"
        }
    }
    // Model IDs ordered as straight 3/4/5, then diagonal 025/030/035.
    // NHSE's values are not contiguous by style; 0x32 and 0x33 are undefined.
    fileprivate var models: [UInt16] {
        switch self {
        case .stone: return [0, 1, 2, 3, 4, 5]
        case .suspension: return [7, 6, 8, 9, 10, 11]
        case .zen: return [19, 12, 20, 21, 22, 23]
        case .log: return [14, 13, 15, 16, 17, 18]
        case .redZen: return [32, 24, 33, 34, 35, 36]
        case .iron: return [39, 25, 40, 41, 42, 43]
        case .reserved: return [26, 27, 28, 29, 30, 31]
        case .wooden: return [44, 37, 45, 46, 47, 48]
        case .brick: return [49, 38, 52, 53, 54, 55]
        }
    }
}

public struct BridgeType: Equatable {
    public let id: UInt16
    public let style: BridgeStyle
    private let geometry: Int
    public init?(_ id: UInt16) {
        for style in BridgeStyle.allCases {
            if let geometry = style.models.firstIndex(of: id) {
                self.id = id; self.style = style; self.geometry = geometry
                return
            }
        }
        return nil
    }
    public var isDiagonal: Bool { geometry >= 3 }
    public var span: Double { isDiagonal ? [2.5, 3, 3.5][geometry - 3] : Double(geometry + 3) }
    public var name: String { "\(style.name) · \(isDiagonal ? "diagonal" : "straight") · \(span.formatted())" }
    /// Keep the bridge's span and straight/diagonal geometry when changing its appearance.
    public func replacingStyle(with style: BridgeStyle) -> BridgeType {
        BridgeType(style.models[geometry])!
    }
}
