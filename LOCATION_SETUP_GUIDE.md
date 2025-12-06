# 📍 Hướng Dẫn Sử Dụng Tính Năng Vị Trí GPS

## ✅ Đã Hoàn Thành

### 1. **Cấu Hình Quyền (Info.plist)**

- ✅ `NSLocationWhenInUseUsageDescription`: Xin quyền truy cập vị trí khi app đang mở
- ✅ `NSLocationAlwaysAndWhenInUseUsageDescription`: Xin quyền truy cập vị trí liên tục (kể cả khi app chạy ngầm)

### 2. **LocationManager.swift** - Quản Lý GPS

```swift
// Tự động xin quyền và bắt đầu theo dõi vị trí
let locationManager = LocationManager()
locationManager.requestPermission()
locationManager.startUpdating()

// Lấy tọa độ hiện tại
if let coords = locationManager.coordinates {
    print("Latitude: \(coords.latitude)")
    print("Longitude: \(coords.longitude)")
}
```

**Tính năng:**

- ✅ Tự động xin quyền vị trí
- ✅ Theo dõi vị trí liên tục (cập nhật khi di chuyển 10m)
- ✅ Xử lý lỗi vị trí
- ✅ Published properties để SwiftUI tự động cập nhật

### 3. **Message.swift** - Mở Rộng Model

**MessageType:**

- `.text` - Tin nhắn văn bản thông thường
- `.sosLocation` - Tin nhắn SOS kèm tọa độ vị trí

**Thuộc tính mới:**

```swift
let latitude: Double?
let longitude: Double?
var hasLocation: Bool // Check xem message có vị trí không
```

### 4. **BridgefyNetworkManager.swift** - Gửi/Nhận Vị Trí

**Gửi SOS kèm vị trí:**

```swift
bridgefyManager.sendSOSWithLocation("🆘 Cần giúp đỡ gấp!")
```

**Tự động:**

- Lấy tọa độ hiện tại từ LocationManager
- Đóng gói thành JSON nhỏ gọn
- Broadcast qua Bridgefy
- Fallback về tin nhắn thường nếu không có GPS

### 5. **SOSMapView.swift** - Hiển Thị Bản Đồ

**Tính năng:**

```swift
SOSMapView(messages: $bridgefyManager.messages)
```

- ✅ Hiển thị tất cả tin nhắn SOS có vị trí trên bản đồ
- ✅ Ghim đỏ với icon cảnh báo
- ✅ Nút "Center on Current Location"
- ✅ Tự động zoom về vị trí mới
- ✅ Hỗ trợ cả SwiftUI Map và UIKit MKMapView

### 6. **ChatView.swift** - Giao Diện Chat

**Nút SOS:**

- ✅ Nút SOS màu đỏ ở góc trái input
- ✅ Tự động gửi vị trí hiện tại khi bấm

**Message Bubble:**

- ✅ Hiển thị tọa độ nếu message có location
- ✅ Nút "Xem bản đồ" mở full-screen map
- ✅ Màu đỏ cho tin nhắn SOS

### 7. **LocationAnnotation.swift** - Custom Annotation

- ✅ Class cho ghim trên bản đồ
- ✅ Chứa thông tin userId, timestamp

---

## 🚀 Cách Sử Dụng

### **A. Gửi SOS từ ChatView**

1. Mở ChatView
2. Bấm nút 🔺 (tam giác đỏ) bên trái input
3. App sẽ gửi "🆘 Cần giúp đỡ gấp!" kèm GPS

### **B. Xem Vị Trí SOS Nhận Được**

1. Tin nhắn SOS sẽ có màu đỏ
2. Dưới tin nhắn hiển thị tọa độ: `16.047079, 108.206230`
3. Bấm "Xem bản đồ" → Mở map full-screen với ghim đỏ

### **C. Xem Tất Cả SOS Trên Bản Đồ**

1. Dùng `SOSMapView` (có thể thêm vào MainTabView)
2. Tất cả SOS sẽ hiển thị thành ghim đỏ
3. Bấm nút 📍 để về vị trí hiện tại

---

## 📊 Kích Thước Dữ Liệu

**JSON gửi đi (MessagePayload):**

```json
{
  "type": "sosLocation",
  "text": "🆘 Cần giúp đỡ gấp!",
  "messageId": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2024-03-15T10:30:00Z",
  "latitude": 16.047079,
  "longitude": 108.20623
}
```

**Ước tính:** ~200-250 bytes (rất nhỏ, phù hợp cho mesh network!)

---

## 🔧 Tinh Chỉnh

### **Tiết Kiệm Pin**

Trong `LocationManager.swift`, đổi:

```swift
manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
manager.distanceFilter = 50 // Chỉ update khi di chuyển 50m
```

### **Cho Phép Chạy Ngầm**

Trong `Info.plist`, thêm:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
</array>
```

### **Tùy Chỉnh Màu Ghim**

Trong `SOSMapView.swift` → `Coordinator`:

```swift
annotationView?.markerTintColor = .orange // Đổi màu
annotationView?.glyphImage = UIImage(systemName: "figure.wave") // Đổi icon
```

---

## ⚠️ Lưu Ý

1. **Quyền Location:**

   - Lần đầu chạy, iOS sẽ hỏi quyền → Người dùng PHẢI chọn "Allow While Using App"
   - Nếu người dùng từ chối → App không thể gửi vị trí

2. **GPS Không Có Trong Simulator:**

   - Simulator: Menu `Features` → `Location` → Chọn `Apple` hoặc custom location
   - Hoặc test trên thiết bị thật

3. **MapKit Cần Internet (Nền Bản Đồ):**

   - Tọa độ vẫn gửi được offline
   - Nhưng hiển thị bản đồ cần có internet
   - Nếu offline, chỉ hiện ghim trên nền trắng

4. **Privacy:**
   - Chỉ gửi tọa độ khi người dùng BẤM NÚT SOS
   - Không tự động gửi vị trí liên tục (trừ khi bạn code thêm)

---

## 📱 Tích Hợp Vào MainTabView

Thêm tab "Bản Đồ" vào `MainTabView.swift`:

```swift
TabView {
    ChatView(bridgefyManager: bridgefyManager)
        .tabItem {
            Label("Chat", systemImage: "message.fill")
        }

    SOSMapView(messages: $bridgefyManager.messages)
        .tabItem {
            Label("Bản Đồ", systemImage: "map.fill")
        }

    RescuersView(bridgefyManager: bridgefyManager)
        .tabItem {
            Label("Rescuers", systemImage: "person.3.fill")
        }
}
```

---

## 🎉 Hoàn Thành!

Bây giờ app của bạn có thể:

- ✅ Gửi vị trí GPS qua mesh network (offline)
- ✅ Hiển thị bản đồ với tất cả vị trí SOS
- ✅ Tiết kiệm pin với cấu hình thông minh
- ✅ UX đẹp với màu sắc phân biệt SOS

**Next Steps:**

- Thêm nút "Navigate" để mở Apple Maps chỉ đường
- Tính khoảng cách đến người cần cứu
- Alert sound khi nhận SOS
