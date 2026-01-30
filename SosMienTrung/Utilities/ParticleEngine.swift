import UIKit

struct WindParticle {
    var position: CGPoint
    var velocity: CGVector
    var life: CGFloat
    var alpha: CGFloat { life }
}

final class ParticleEngine {
    private(set) var particles: [WindParticle] = []
    private let maxParticles: Int
    private var bounds: CGRect

    // base wind vector in px/sec applied to particles
    var baseWind: CGVector = .zero

    init(maxParticles: Int = 800, bounds: CGRect = .zero) {
        self.maxParticles = maxParticles
        self.bounds = bounds
        particles = []
        resetAll()
    }

    func resize(_ newBounds: CGRect) {
        bounds = newBounds
        // optionally re-seed particles to new bounds
        if particles.isEmpty { resetAll() }
    }

    private func resetAll() {
        particles = (0..<maxParticles).map { _ in createParticle() }
    }

    private func createParticle() -> WindParticle {
        let x = CGFloat.random(in: bounds.minX...bounds.maxX)
        let y = CGFloat.random(in: bounds.minY...bounds.maxY)
        // small random velocity around base
        let jitterX = CGFloat.random(in: -0.2...0.2)
        let jitterY = CGFloat.random(in: -0.2...0.2)
        let vel = CGVector(dx: baseWind.dx + jitterX, dy: baseWind.dy + jitterY)
        let life = CGFloat.random(in: 0.4...1.0)
        return WindParticle(position: CGPoint(x: x, y: y), velocity: vel, life: life)
    }

    func reset(_ index: Int) {
        guard index >= 0 && index < particles.count else { return }
        particles[index] = createParticle()
    }

    /// Update particles with a per-particle velocity sampler (velocity in px/sec)
    func update(dt: CGFloat, velocitySampler: (CGPoint) -> CGVector) {
        guard dt > 0 else { return }
        for i in particles.indices {
            var p = particles[i]
            // sample desired velocity for particle position
            let sampled = velocitySampler(p.position)
            // blend towards sampled velocity for smoothness
            let blend: CGFloat = 0.18
            p.velocity.dx = p.velocity.dx * (1 - blend) + sampled.dx * blend + CGFloat.random(in: -0.02...0.02)
            p.velocity.dy = p.velocity.dy * (1 - blend) + sampled.dy * blend + CGFloat.random(in: -0.02...0.02)

            p.position.x += p.velocity.dx * dt
            p.position.y += p.velocity.dy * dt
            p.life -= dt * 0.25

            if p.life <= 0 || !bounds.contains(p.position) {
                p = createParticle()
            }
            particles[i] = p
        }
    }
}
