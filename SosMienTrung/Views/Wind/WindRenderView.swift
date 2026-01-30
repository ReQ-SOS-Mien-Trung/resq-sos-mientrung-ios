import UIKit
import MapKit

/// A prototype particle renderer using CoreGraphics drawn into a backing image.
final class WindRenderView: UIView {
    private var engine: ParticleEngine!
    private var displayLink: CADisplayLink?
    private var lastTs: CFTimeInterval = 0

    // wind in m/s and deg (from) — kept for single-point fallback
    var windSpeed: Double? {
        didSet { updateBaseWind() }
    }
    var windDegFrom: Int? {
        didSet { updateBaseWind() }
    }

    // optional spatial wind field (grid)
    var windField: GridWindField?

    // reference to mapView to convert point<->coord
    weak var mapView: MKMapView?

    // conversion px per meter (updated from mapView)
    var pxPerMeter: CGFloat = 0.5 {
        didSet { updateBaseWind() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        isOpaque = false
        backgroundColor = .clear
        engine = ParticleEngine(maxParticles: 1500, bounds: bounds)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        engine.resize(bounds)
    }

    func start() {
        stop()
        lastTs = CACurrentMediaTime()
        displayLink = CADisplayLink(target: self, selector: #selector(step))
        displayLink?.add(to: .main, forMode: .common)
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        let now = link.timestamp
        let dt = CGFloat(max(0, now - lastTs))
        lastTs = now

        // sampler: for a particle at screen point -> desired velocity in px/sec
        let sampler: (CGPoint) -> CGVector = { [weak self] point in
            guard let self = self else { return .zero }
            // if we have a windField and mapView, sample spatially
            if let field = self.windField, let map = self.mapView {
                let coord = map.convert(point, toCoordinateFrom: self)
                let s = field.sample(lat: coord.latitude, lon: coord.longitude)
                // s.u/s.v in m/s; convert to px/s
                let dx = CGFloat(s.u) * self.pxPerMeter
                let dy = CGFloat(-s.v) * self.pxPerMeter
                return CGVector(dx: dx, dy: dy)
            }
            // fallback to baseWind
            return self.engine.baseWind
        }

        engine.update(dt: dt, velocitySampler: sampler)
        renderToLayer()
    }

    private func updateBaseWind() {
        // keep a fallback baseWind if no grid present
        guard let sp = windSpeed, let deg = windDegFrom else { engine.baseWind = .zero; return }
        let rad = Double(deg) * .pi / 180.0
        let u = sp * sin(rad)
        let v = sp * cos(rad)
        let dx = CGFloat(u) * pxPerMeter
        let dy = CGFloat(-v) * pxPerMeter
        engine.baseWind = CGVector(dx: dx, dy: dy)
    }

    private func renderToLayer() {
        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        let img = renderer.image { ctx in
            ctx.cgContext.setLineCap(.round)
            for p in engine.particles {
                let lifeAlpha = max(0.0, min(1.0, p.life))
                // length proportional to velocity magnitude — increased for better visibility
                let speed_px = sqrt(p.velocity.dx * p.velocity.dx + p.velocity.dy * p.velocity.dy)
                let len = speed_px * 0.15  // increased from 0.06 to 0.15
                let end = CGPoint(x: p.position.x + p.velocity.dx * CGFloat(len), y: p.position.y + p.velocity.dy * CGFloat(len))
                let path = UIBezierPath()
                path.move(to: p.position)
                path.addLine(to: end)
                ctx.cgContext.setLineWidth(1.2)  // increased from 0.9 to 1.2
                // color ramp based on speed magnitude (approx)
                let speed = speed_px / max(pxPerMeter, 0.0001)
                let color = colorForSpeed(speed)
                // increased alpha from 0.18 to 0.35 for better visibility
                ctx.cgContext.setStrokeColor(color.withAlphaComponent(0.35 * lifeAlpha).cgColor)
                ctx.cgContext.addPath(path.cgPath)
                ctx.cgContext.strokePath()
            }
        }
        layer.contents = img.cgImage
    }

    private func colorForSpeed(_ speed: CGFloat) -> UIColor {
        // speed in m/s approx
        switch speed {
        case 0..<3: return UIColor.systemTeal // xanh
        case 3..<7: return UIColor.systemYellow
        case 7..<14: return UIColor.systemRed
        default: return UIColor.systemPurple
        }
    }
}
