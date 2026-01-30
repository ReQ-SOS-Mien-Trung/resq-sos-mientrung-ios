import Foundation
import CoreLocation

/// Small grid of wind vectors (u,v) in m/s sampled at grid nodes.
final class GridWindField {
    struct Cell {
        var lat: Double
        var lon: Double
        var u: Double
        var v: Double
        var speed: Double
    }

    private(set) var rows: Int = 0
    private(set) var cols: Int = 0
    private var cells: [Cell] = [] // row-major: r*cols + c

    var isReady: Bool { !cells.isEmpty }

    init() {}

    func indexFor(r: Int, c: Int) -> Int { r * cols + c }

    func cellAt(r: Int, c: Int) -> Cell? {
        guard r >= 0 && r < rows && c >= 0 && c < cols else { return nil }
        return cells[indexFor(r: r, c: c)]
    }

    /// Build grid centered at center coordinate, covering latSpan/lonSpan, with given rows x cols.
    /// This will call WeatherService for each grid node (async). Use small rows/cols to avoid rate limits.
    @available(iOS 15.0, *)
    func refresh(center: CLLocationCoordinate2D, latSpan: Double, lonSpan: Double, rows: Int, cols: Int) async {
        self.rows = rows
        self.cols = cols
        cells = Array(repeating: Cell(lat: 0, lon: 0, u: 0, v: 0, speed: 0), count: rows * cols)

        let latStart = center.latitude - latSpan/2
        let lonStart = center.longitude - lonSpan/2
        let latStep = latSpan / Double(max(1, rows - 1))
        let lonStep = lonSpan / Double(max(1, cols - 1))

        await withTaskGroup(of: (Int, Int, Cell?).self) { group in
            for r in 0..<rows {
                for c in 0..<cols {
                    let lat = latStart + Double(r) * latStep
                    let lon = lonStart + Double(c) * lonStep
                    group.addTask {
                        do {
                            let resp = try await WeatherService.fetchOneCall(lat: lat, lon: lon, exclude: ["minutely","hourly","daily","alerts"], units: "metric")
                            let speed = resp.current?.wind_speed ?? 0.0
                            let deg = resp.current?.wind_deg ?? 0
                            let rad = Double(deg) * .pi / 180.0
                            // Windy-style u/v
                            let u = speed * sin(rad)
                            let v = speed * cos(rad)
                            let cell = Cell(lat: lat, lon: lon, u: u, v: v, speed: speed)
                            return (r, c, cell)
                        } catch {
                            return (r, c, Cell(lat: lat, lon: lon, u: 0, v: 0, speed: 0))
                        }
                    }
                }
            }

            for await result in group {
                let (r, c, cellOpt) = result
                if let cell = cellOpt {
                    cells[indexFor(r: r, c: c)] = cell
                }
            }
        }
    }

    /// Sample u,v,speed at lat/lon using bilinear interpolation across grid cells. Returns zeros if grid not ready.
    func sample(lat: Double, lon: Double) -> (u: Double, v: Double, speed: Double) {
        guard rows > 0 && cols > 0 else { return (0,0,0) }

        // Find fractional position within grid
        // Compute extents
        guard let first = cellAt(r: 0, c: 0), let last = cellAt(r: rows - 1, c: cols - 1) else { return (0,0,0) }
        let latMin = first.lat
        let latMax = last.lat
        let lonMin = first.lon
        let lonMax = last.lon
        if latMax == latMin || lonMax == lonMin { return (0,0,0) }

        let fy = (lat - latMin) / (latMax - latMin)
        let fx = (lon - lonMin) / (lonMax - lonMin)
        let ry = fy * Double(rows - 1)
        let rx = fx * Double(cols - 1)
        let r0 = Int(floor(ry))
        let c0 = Int(floor(rx))
        let r1 = min(rows - 1, r0 + 1)
        let c1 = min(cols - 1, c0 + 1)
        let dy = ry - Double(r0)
        let dx = rx - Double(c0)

        func at(_ r: Int, _ c: Int) -> Cell { cellAt(r: r, c: c) ?? Cell(lat:0,lon:0,u:0,v:0,speed:0) }

        let c00 = at(r0,c0)
        let c10 = at(r1,c0)
        let c01 = at(r0,c1)
        let c11 = at(r1,c1)

        let u0 = c00.u * (1-dy) + c10.u * dy
        let u1 = c01.u * (1-dy) + c11.u * dy
        let u = u0 * (1-dx) + u1 * dx

        let v0 = c00.v * (1-dy) + c10.v * dy
        let v1 = c01.v * (1-dy) + c11.v * dy
        let v = v0 * (1-dx) + v1 * dx

        let s0 = c00.speed * (1-dy) + c10.speed * dy
        let s1 = c01.speed * (1-dy) + c11.speed * dy
        let s = s0 * (1-dx) + s1 * dx

        return (u, v, s)
    }
}
