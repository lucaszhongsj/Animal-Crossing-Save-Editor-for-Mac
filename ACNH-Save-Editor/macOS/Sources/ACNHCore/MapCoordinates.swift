import Foundation
import CoreGraphics

public struct MapCell: Equatable {
    public let x: Int
    public let y: Int
    public init(x: Int, y: Int) { self.x = x; self.y = y }
}

public struct MapPoint: Equatable {
    public let x: Double
    public let y: Double
}

/// Converts canvas points to save coordinates without selecting cells outside a layer.
public enum MapCoordinates {
    /// NHSE's full map is 288×256 pixels, twice this canvas's 144×128 terrain grid.
    /// Building positions already include the ocean border; no terrain/item offset applies.
    public static func buildingPoint(_ position: BuildingPosition, zoom: Double) -> MapPoint {
        MapPoint(x: Double(position.x) * zoom / 2, y: Double(position.y) * zoom / 2)
    }

    /// The plaza uses an upper-left anchor, unlike the centered building guides.
    public static func plazaBounds(_ position: PlazaPosition, zoom: Double) -> CGRect {
        CGRect(x: Double(position.x) * zoom / 2, y: Double(position.y) * zoom / 2,
               width: 12 * zoom, height: 10 * zoom)
    }

    public static func plazaAt(x: Double, y: Double, zoom: Double, position: PlazaPosition) -> Bool {
        guard let point = worldPoint(x: x, y: y, zoom: zoom),
              (0..<144).contains(point.x), (0..<128).contains(point.y) else { return false }
        return plazaBounds(position, zoom: zoom).contains(CGPoint(x: x, y: y))
    }

    public static func nearestBuilding(x: Double, y: Double, zoom: Double, buildings: [MapBuilding]) -> Int? {
        guard let point = worldPoint(x: x, y: y, zoom: zoom),
              (0..<144).contains(point.x), (0..<128).contains(point.y) else { return nil }
        var nearest: Int?
        var distance = Double.greatestFiniteMagnitude
        for building in buildings where building.kind != 0 && building.position.x < IslandLayout.buildingWidth && building.position.y < IslandLayout.buildingHeight {
            let location = buildingPoint(building.position, zoom: zoom)
            let dx = location.x - x, dy = location.y - y
            let candidate = dx * dx + dy * dy
            if candidate < distance { nearest = building.id; distance = candidate }
        }
        return nearest
    }

    /// Dimension guides stay centered on the existing saved marker. The exact
    /// per-model anchor and collision mask are not yet verified.
    public static func buildingBounds(_ building: MapBuilding, zoom: Double) -> CGRect {
        let point = buildingPoint(building.position, zoom: zoom)
        let plot = BuildingFootprint.forBuilding(building)
        let width = (plot?.width ?? 3) * zoom
        let depth = (plot?.depth ?? 3) * zoom
        return CGRect(x: point.x - width / 2, y: point.y - depth / 2, width: width, height: depth)
    }

    public static func buildingAt(x: Double, y: Double, zoom: Double, buildings: [MapBuilding]) -> Int? {
        guard let point = worldPoint(x: x, y: y, zoom: zoom),
              (0..<144).contains(point.x), (0..<128).contains(point.y) else { return nil }
        let candidates = buildings.filter {
            $0.kind != 0 && $0.position.x < IslandLayout.buildingWidth && $0.position.y < IslandLayout.buildingHeight &&
            buildingBounds($0, zoom: zoom).contains(CGPoint(x: x, y: y))
        }
        return nearestBuilding(x: x, y: y, zoom: zoom, buildings: candidates)
    }

    public static func terrain(x: Double, y: Double, zoom: Double) -> MapCell? {
        guard let point = worldPoint(x: x, y: y, zoom: zoom),
              (16..<128).contains(point.x), (16..<112).contains(point.y) else { return nil }
        return MapCell(x: Int(floor(point.x)) - 16, y: Int(floor(point.y)) - 16)
    }

    public static func item(x: Double, y: Double, zoom: Double) -> MapCell? {
        guard let point = worldPoint(x: x, y: y, zoom: zoom),
              (0..<144).contains(point.x), (16..<112).contains(point.y) else { return nil }
        return MapCell(x: Int(floor(point.x * 2)), y: Int(floor((point.y - 16) * 2)))
    }

    /// Item coordinates are half tiles; an aligned full-tile root uses even values.
    public static func snappedItemCell(_ cell: MapCell) -> MapCell {
        MapCell(x: min(286, max(0, cell.x)) / 2 * 2,
                y: min(190, max(0, cell.y)) / 2 * 2)
    }

    public static func movingItemCell(_ cell: MapCell, dx: Int, dy: Int, snapped: Bool) -> MapCell {
        let step = snapped ? 2 : 1
        // Keep the phase of existing odd-coordinate roots when moving by full tiles.
        let minX = cell.x % step, minY = cell.y % step
        let maxX = 287 - (287 - minX) % step, maxY = 191 - (191 - minY) % step
        return MapCell(x: min(maxX, max(minX, cell.x + dx * step)),
                       y: min(maxY, max(minY, cell.y + dy * step)))
    }

    private static func worldPoint(x: Double, y: Double, zoom: Double) -> (x: Double, y: Double)? {
        guard x.isFinite, y.isFinite, zoom.isFinite, zoom > 0 else { return nil }
        return (x / zoom, y / zoom)
    }
}
