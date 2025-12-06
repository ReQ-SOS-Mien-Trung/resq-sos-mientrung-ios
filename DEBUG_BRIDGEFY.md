# 🔍 Debug: Tại Sao Không Tìm Được Người Lân Cận?

## 📱 Cách Bridgefy Hoạt Động

Bridgefy sử dụng **Bluetooth Low Energy (BLE)** để tạo mesh network:

```
Device A ←→ [Bluetooth] ←→ Device B ←→ Device C
```

**QUAN TRỌNG:** Để test được, bạn cần **ÍT NHẤT 2 thiết bị**:

- 2 iPhone thật, HOẶC
- 1 iPhone + 1 iPad, HOẶC
- Không thể test trên Simulator (Simulator không có Bluetooth)

---

## ✅ Checklist Kiểm Tra

### 1. **Bluetooth Đã Bật?**

```
Settings → Bluetooth → ON (màu xanh)
```

### 2. **Quyền Bluetooth Đã Cấp?**

```
Settings → Privacy & Security → Bluetooth → SosMienTrung → ON
```

### 3. **App Đang Chạy Trên 2 Thiết Bị?**

- Build app lên 2 thiết bị khác nhau
- Mở app trên CẢ HAI thiết bị đồng thời
- Để gần nhau (trong vòng ~70 mét)

### 4. **Kiểm Tra Console Log**

Mở Xcode Console khi chạy app, bạn sẽ thấy:

**Nếu thành công:**

```
✅ Bridgefy STARTED with userId: 550e8400-e29b-41d4-a716-446655440000
🔗 Connected with: 123e4567-e89b-12d3-a456-426614174000
📊 Total connected users: 1
```

**Nếu lỗi:**

```
❌ Bridgefy FAILED TO START: Bluetooth is off
❌ Failed to establish secure connection with ...: Permission denied
```

---

## 🧪 Test Scenarios

### Scenario 1: Test Broadcast (Không Cần Kết Nối)

**Bridgefy broadcast mode KHÔNG CẦN `connectedUsers`!**

1. Mở app trên Device A
2. Mở app trên Device B (để gần Device A)
3. Trên Device A: Gửi tin nhắn "Hello"
4. **Device B sẽ NHẬN ĐƯỢC** tin nhắn "Hello"

**Lưu ý:** `connectedUsers` chỉ track kết nối trực tiếp, nhưng broadcast vẫn hoạt động!

### Scenario 2: Test SOS Location

1. Bật Location trên cả 2 thiết bị
2. Bấm nút 🔺 SOS
3. Device kia sẽ nhận tin nhắn màu đỏ với tọa độ

---

## 🐛 Debug Commands

### 1. Bật Verbose Logging (Đã bật rồi)

```swift
verboseLogging: true // Line 18 BridgefyNetworkManager.swift
```

### 2. Kiểm Tra Bridgefy Status

Thêm vào ChatView để hiển thị status:

```swift
Text("Bridgefy Status: \(bridgefyManager.bridgefy == nil ? "Not started" : "Running")")
```

### 3. Force Bluetooth Check

```swift
import CoreBluetooth

let manager = CBCentralManager()
if manager.state == .poweredOn {
    print("✅ Bluetooth is ON")
} else {
    print("❌ Bluetooth is OFF or Unauthorized")
}
```

---

## ⚠️ Common Issues

### Issue 1: "0 rescuers connected" nhưng vẫn nhận tin nhắn

**BÌNH THƯỜNG!** Bridgefy broadcast không cần connection tracking.

**Giải pháp:** Tin nhắn vẫn gửi được, đừng lo!

### Issue 2: Không nhận được tin nhắn nào

**Nguyên nhân:**

- Bluetooth tắt
- Quyền Bluetooth bị từ chối
- Không có thiết bị thứ 2 chạy app
- 2 thiết bị cách xa nhau (>70m)

**Giải pháp:**

1. Check log: `❌ Bridgefy FAILED TO START`
2. Check Settings → Bluetooth → ON
3. Check Settings → Privacy → Bluetooth → Allow

### Issue 3: API Key Invalid

**Lỗi:** `Invalid API key` hoặc `Unauthorized`

**Giải pháp:**

1. Đăng ký API key mới tại: https://bridgefy.me/
2. Thay key tại line 18:

```swift
let bridgefy = try Bridgefy(withApiKey: "YOUR_NEW_KEY", ...)
```

---

## 📊 Expected Console Output

### Khi App Start Thành Công:

```
✅ Bridgefy STARTED with userId: abc123...
```

### Khi Tìm Thấy Người Lân Cận:

```
🔗 Connected with: def456...
📊 Total connected users: 1
🔗 Connected with: ghi789...
📊 Total connected users: 2
```

### Khi Gửi Tin Nhắn:

```
✅ Message sent successfully: msg-uuid-123
```

### Khi Nhận Tin Nhắn:

```
📨 Received message msg-uuid-456 via broadcast: Hello!
```

---

## 🚀 Test Nhanh (1 Phút)

**Bước 1:** Build app lên 2 iPhone
**Bước 2:** Mở app trên CẢ 2 iPhone
**Bước 3:** Gõ "Test" trên iPhone A → Send
**Bước 4:** Check iPhone B → Phải thấy "Test"

**Nếu thấy → ✅ Hoạt động!**
**Nếu không → Check Console log ở trên**

---

## 💡 Tips

### Tip 1: Bridgefy Cần Thời Gian Khởi Động

Đợi ~5-10 giây sau khi mở app để Bridgefy tìm peers.

### Tip 2: Broadcast ≠ Connected Users

- `connectedUsers.count` = số kết nối trực tiếp
- Broadcast message = gửi cho TẤT CẢ trong vùng (không cần connect)

### Tip 3: Test Trên Thiết Bị Thật

Simulator KHÔNG HỖ TRỢ Bluetooth → PHẢI test trên iPhone thật.

---

## 🔧 Thêm Debug UI (Optional)

Thêm vào ChatView để debug:

```swift
// Debug Panel (hidden in production)
if true { // Change to false khi release
    VStack(alignment: .leading, spacing: 4) {
        Text("DEBUG INFO")
            .font(.caption2.bold())
            .foregroundColor(.yellow)
        Text("Bridgefy: \(bridgefyManager.bridgefy == nil ? "❌ Not started" : "✅ Running")")
            .font(.caption2)
            .foregroundColor(.white.opacity(0.7))
        Text("API Key: ...cac0 (valid)")
            .font(.caption2)
            .foregroundColor(.white.opacity(0.7))
        Text("Bluetooth: Check Settings")
            .font(.caption2)
            .foregroundColor(.white.opacity(0.7))
    }
    .padding()
    .background(Color.red.opacity(0.3))
    .cornerRadius(8)
}
```

---

## ❓ FAQ

**Q: Tại sao "0 rescuers connected"?**
A: Bridgefy broadcast không track connections. Tin nhắn vẫn gửi được!

**Q: Cần bao nhiêu thiết bị để test?**
A: Tối thiểu 2 thiết bị iOS thật.

**Q: Khoảng cách tối đa?**
A: ~70 mét (trong điều kiện lý tưởng, không vật cản).

**Q: Có hoạt động khi tắt màn hình?**
A: Cần thêm background mode (chưa config).

---

## 🎯 Next Steps

1. **Build app lên 2 thiết bị**
2. **Check Console log** → Tìm dòng "✅ Bridgefy STARTED"
3. **Gửi thử tin nhắn** → Check thiết bị kia
4. **Báo lại log** nếu có lỗi!
