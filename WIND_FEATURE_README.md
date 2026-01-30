# Wind Feature — Hướng dẫn kiểm tra và chạy

## Tóm tắt tính năng đã triển khai

### Phase 1 + Phase 2 hoàn tất ✅
- **Particle Engine** (`ParticleEngine.swift`): quản lý ~700 particle gió, update vị trí theo vector gió.
- **Wind Render View** (`WindRenderView.swift`): vẽ particle dạng vệt trắng lên bản đồ bằng CoreGraphics.
- **Grid Wind Field** (`GridWindField.swift`): sampling grid 5x5 từ OpenWeather One Call, bilinear interpolation cho từng particle.
- **Weather Service** (`WeatherService.swift`): fetch dữ liệu gió từ One Call 3.0 API.
- **UI Integration**: `SOSMapView` + `WindIndicatorView` hiển thị mũi tên hướng gió và particle khi chọn lớp "Hướng + tốc độ gió".

## Cách chạy và kiểm tra

### 1. Đảm bảo API key hợp lệ
- Mở `SosMienTrung/Keys.plist` và đảm bảo `OPENWEATHER_API_KEY` có giá trị thật (không phải `YOUR_OPENWEATHER_API_KEY`).
- One Call 3.0 có thể yêu cầu paid plan — check tài khoản OpenWeather.

### 2. Build và chạy
```bash
# Mở workspace (không phải .xcodeproj)
open SosMienTrung.xcworkspace

# Chọn target SosMienTrung và thiết bị/simulator
# Build: Cmd+B
# Run: Cmd+R
```

### 3. Sử dụng
1. App khởi động → chọn tab có "Bản đồ Thiên tai" (SOSMapView).
2. Trong picker dưới cùng, chọn **"Hướng + tốc độ gió"** (wind_new).
3. Quan sát:
   - Mũi tên chỉ hướng gió xuất hiện ở giữa màn hình (WindIndicatorView).
   - Sau vài giây, grid sẽ refresh (5x5 = 25 API calls) và particle bắt đầu hiển thị trên bản đồ.
   - Particle di chuyển theo vector gió (màu xanh/vàng/đỏ/tím tùy cường độ).

### 4. Debugging
- Mở Console (Xcode → View → Debug Area → Activate Console).
- Log xuất hiện:
  - `⚠️ WARNING: OpenWeatherMap API key...` — nếu key chưa set.
  - `Failed to fetch wind:` — nếu API trả lỗi (401/402/403 hoặc rate limit).
  - Grid refresh hoàn tất khi không có lỗi log.

### 5. Điều chỉnh tham số (nếu cần)

#### Giảm chi phí API (ít API calls)
- Mở `SosMienTrung/SOSMapView.swift`, tìm dòng:
  ```swift
  await coordinator?.gridField?.refresh(..., rows: 5, cols: 5)
  ```
- Đổi thành `rows: 3, cols: 3` (9 calls) hoặc `rows: 2, cols: 2` (4 calls).

#### Tăng/giảm số particle
- Mở `SosMienTrung/WindRenderView.swift`, tìm:
  ```swift
  engine = ParticleEngine(maxParticles: 700, bounds: bounds)
  ```
- Đổi `700` thành số khác (100-2000 tùy hiệu năng).

#### Điều chỉnh màu/độ dày vệt
- Trong `WindRenderView.swift`, tìm `colorForSpeed(_:)` và `renderToLayer()`:
  ```swift
  ctx.cgContext.setLineWidth(0.9) // độ dày
  .withAlphaComponent(0.18 * lifeAlpha) // độ trong suốt
  ```

## Kiến trúc code

```
SOSMapView (SwiftUI)
  ↓
WeatherMapView (UIViewRepresentable)
  ↓
MKMapView + WindRenderView (UIView overlay)
  ↓
ParticleEngine + GridWindField
  ↓
WeatherService → OpenWeather One Call 3.0
```

## Giới hạn hiện tại

- **API cost**: Grid 5x5 = 25 API calls mỗi lần refresh. Cân nhắc giảm hoặc server-side cache.
- **Hiệu năng**: CoreGraphics bitmap render — đủ cho ~700-1000 particle; nếu muốn >2k particle, nâng cấp sang Metal (Phase 3).
- **Latency**: Grid refresh khoảng 2-5 giây (tùy network + API) — particle chờ grid sẵn sàng.

## Next Steps (tùy chọn)

- [ ] Giảm API cost: 3x3 grid hoặc server-side.
- [ ] Nâng cấp Metal renderer (Phase 3) cho hiệu năng cao.
- [ ] Thêm UI controls (density slider, speed multiplier, legend).
- [ ] Cache grid và refresh định kỳ (5-10 phút) thay vì mỗi lần region thay đổi.

## Troubleshooting

| Vấn đề | Nguyên nhân có thể | Giải pháp |
|--------|-------------------|-----------|
| Không thấy particle | API key chưa set hoặc không hợp lệ | Kiểm tra Keys.plist + Console log |
| Particle không di chuyển | Grid chưa fetch xong hoặc lỗi API | Đợi vài giây, check Console |
| App lag khi chọn wind layer | Quá nhiều particle hoặc CPU chậm | Giảm maxParticles xuống 300-500 |
| HTTP 401/402/403 | API key sai hoặc plan không bao gồm One Call 3.0 | Check OpenWeather account/plan |
| HTTP 429 | Rate limit | Đợi hoặc giảm grid size |

---

✅ **Sẵn sàng chạy thử!**
