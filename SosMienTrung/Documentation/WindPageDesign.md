**Wind Page Design — SosMienTrung**

Mục tiêu

- Hiển thị lớp gió dạng particle (giống Windy) chồng lên Apple Map (MKMapView).
- Mượt, ít tốn CPU/GPU, scale theo zoom, và phản ánh biến đổi gió theo vị trí.

1. Tóm tắt kiến trúc

- MKMapView: bản đồ chính (chỉ để hiển thị tile + tương tác).
- Transparent Render Layer (UIView/Metal view) đặt trên MKMapView: nơi vẽ các particle.
- Particle Engine: cập nhật trạng thái particle mỗi frame (CADisplayLink).
- Grid Wind Field: dữ liệu gió (u,v) chia theo ô grid cố định (ví dụ 0.25°) cho toàn bản đồ hiện tại.
- Data Source: OpenWeather One Call 3.0 (lấy `current.wind_speed`, `current.wind_deg`) hoặc server side cung cấp grid dữ liệu nếu cần cover toàn map.

2. Dữ liệu gốc và chuyển vector

- OpenWeather trả: `wind_speed` (m/s), `wind_deg` (độ, 0 = Bắc, 90 = Đông).
- Chuyển sang vector (Windy-style):
  - rad = wind_deg \* pi / 180
  - u = wind_speed \* sin(rad) // X: Đông +, Tây -
  - v = wind_speed \* cos(rad) // Y: Bắc +, Nam -
- Lưu ở mỗi ô (cell) của grid: (u, v, speed)

3. Grid và sampling

- Chia không gian (lat/lon) thành grid; gợi ý: 0.25° (~27km) hoặc 0.1° (~11km) tùy cần chính xác/hiệu năng.
- Khi bản đồ zoom gần, tăng density particle và có thể nội suy vector giữa ô (bilinear interpolation).
- Lưu cache grid cho tiles/region, refresh sau X phút hoặc khi API trả lỗi/quota.

4. Particle model (cốt lõi)

- struct WindParticle {
  var position: CGPoint // trên màn hình (pixel)
  var velocity: CGVector // pixel/sec (từ vector gió chuyển sang màn hình)
  var life: CGFloat // 0..1
  var alpha: CGFloat
  }

- Update loop ~60 FPS (CADisplayLink): dt = elapsedSec
  - sample wind vector ở vị trí particle (lat/lon ↔ screen)
  - convert world vector (m/s) → screen velocity (px/s): velocity = worldVec _ metersPerSecondToPixels _ scale
  - position += velocity \* dt
  - life -= dt \* lifeDecay
  - alpha = life
  - if life <= 0 or off-screen: reset particle at random location within view (or along upstream boundary)

5. Mapping world vector → screen velocity

- We need conversion factor: wind (m/s) → pixel/sec on current map scale.
- Steps:
  - Decide a reference physical distance for 1 pixel at current zoom/latitude:
    - Use MKMapView to convert two close coordinates to points: e.g., 1/1000 degree (or 1 meter using CLLocationDistance) to screen pixels and compute pxPerMeter.
  - velocity_px = wind_mps \* pxPerMeter
  - Multiply by an animation speed multiplier to tune look (e.g., \* 0.6)
- Also scale length of streak drawn ∝ wind speed.

6. Rendering (quan trọng)

- Khuyến nghị: Metal (MTKView) cho hiệu năng tốt nhất khi nhiều particle (>5k), CAShapeLayer/CGContext cho prototype nhẹ (~1k particles).
- Rendering approach (CAShapeLayer/CGContext prototype):
  - Maintain an offscreen CGContext/bitmap layer or draw in `draw(_:)` of a `UIView` using Core Graphics.
  - For each particle, draw a short line from `p` to `p + v*lengthFactor` with stroke color and alpha = p.alpha \* globalAlpha.
  - Use `setBlendMode(.plusLighter)` hoặc `.normal` tùy hiệu ứng.
- Metal approach (production):
  - Use a compute shader or vertex shader instanced draw to render all particles in single draw call.
  - Store particle data in buffer and update via CPU or compute.
  - Render as lines or textured quads with additive blending.

7. Color mapping

- Map speed -> color ramp:
  - 0 - 3 m/s: xanh ( nhẹ )
  - 3 - 7 m/s: vàng ( trung bình )
  - 7 - 14 m/s: đỏ ( mạnh )
  - > 14 m/s: tím ( bão )
- Or use continuous HSV ramp from blue → yellow → red → purple.
- Line width: small (0.8 - 1.4 px), alpha low (0.12 - 0.35) so không che bản đồ.

8. Integration với MapKit

- Place a transparent `RenderView` on top of `MKMapView` in `UIViewRepresentable`:
  - In `makeUIView`, add `mapView.addSubview(renderView)` and pin frame = mapView.bounds and autoresizing mask.
  - In `mapView(_:regionDidChangeAnimated:)` update conversion factors and optionally reposition/reset particles.
- When map pans/zooms: do NOT recompute all particles each frame; instead:
  - Update particle positions by converting their lat/lon → screen coords when region changes (expensive) OR use screen-space particles and allow them to drift even as map moves (less accurate). Recommended: keep particles in lat/lon and compute screen position each frame using `mapView.convert(_:toPointToView:)` — but that is expensive.
  - Efficient approach: store particle position in screen coords; when map region changes, apply a delta translation to all particles based on map movement; when zoom changes, scale velocities and particle sizes accordingly.

9. Grid-based local wind

- For realistic effects, do not use a single wind vector for whole map.
- If OpenWeather only returns single point `current` for a coordinate, sample many coordinates (grid cells) by calling API per cell — but One Call API per coordinate can be rate-limited and costly.
- Better options:
  - Precompute server-side grid and serve a raster/vector field (recommended for production).
  - Or fetch at few key points and interpolate.

10. Performance tips

- Use Metal for >2k particles.
- Use instanced draws and avoid per-particle CoreGraphics calls.
- Batch updates and redraw at <60Hz if needed.
- Limit particle count by screen size / density: e.g., particles = min( max(1000, areaFactor), 6000 )

11. UX controls

- Layer selector (already exists): when `wind_new` selected show wind page.
- Controls: density slider, speed multiplier, color palette toggle, pause/play, sample radius.
- Legend: color swatches → meaning.

12. Edge cases & notes

- API limits: One Call 3.0 may require paid plan.
- If you only have single-point wind (center), display arrow as current small indicator (already implemented) and show particle map only when grid data available.
- Respect background threads: heavy work off main thread; rendering must stay on main/Metal.

13. Implementation plan (phases)

- Phase 1 (prototype, quick):
  - Implement `RenderView` (UIView) + `ParticleEngine` using CAShapeLayer/CoreGraphics.
  - Use center point wind vector for whole view (fast) so particle field visible.
  - Integrate with `WeatherService` to fetch wind for map center and feed engine.
- Phase 2 (better fidelity):
  - Implement grid sampling (small grid 5x5) around map center, bilinear interpolation for particles.
  - Improve mapping meters->px and zoom scaling.
- Phase 3 (production):
  - Switch to Metal-based renderer.
  - Precompute grid server-side if API cost/time.

14. Next steps (choose one)

- [ ] Tôi triển khai prototype CAShapeLayer trong repo (khoảng 1–2 giờ). Tôi sẽ:
  - add `WindRenderView.swift` + `ParticleEngine.swift`,
  - wire to `WeatherService` and `SOSMapView` to fetch center wind and show particle prototype.
- [ ] Tôi thiết kế Metal pipeline và code mẫu (cao cấp).

---

If you want, I can start Phase 1 now and implement a CAShapeLayer-based prototype. Reply 'phase1' to start, or pick another next step.
