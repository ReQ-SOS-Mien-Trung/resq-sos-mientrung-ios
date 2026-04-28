# ResQ SOS iOS App - Capstone Project

Dự án Hệ thống Hỗ trợ Cứu hộ và Điều phối Khẩn cấp (ResQ SOS) - Phiên bản dành cho người dùng di động (iOS Application).

## 1. Công nghệ sử dụng (Third-party Libraries & Frameworks)

Dự án được phát triển trên nền tảng iOS hiện đại với các công nghệ:

- **Ngôn ngữ chính:** Swift 5.10.
- **Giao diện:** SwiftUI (Declarative UI).
- **Kết nối ngoại vi (Offline Mesh):** Bridgefy SDK (Sử dụng Bluetooth/Wifi Direct để liên lạc khi mất internet).
- **Backend & Cloud Services:**
  - Firebase (Authentication, Cloud Messaging, Analytics).
  - Google Sign-In SDK.
  - Recaptcha Enterprise.
- **Bản đồ & Định vị:** Apple Maps, CoreLocation.
- **Lưu trữ dữ liệu:** Core Data (Local Persistence for Offline Requests).
- **Quản lý thư viện:** CocoaPods.
- **Công cụ hỗ trợ:** SwiftLint (Code Quality), SF Symbols.

## 2. Hướng dẫn cài đặt (Installation Guide)

Đảm bảo bạn đang sử dụng macOS và đã cài đặt **Xcode (phiên bản 15.0+)**.

### Bước 1: Cài đặt CocoaPods (nếu chưa có)

```bash
sudo gem install cocoapods
```

### Bước 2: Cài đặt các thư viện phụ thuộc

Di chuyển vào thư mục gốc của dự án và chạy:

```bash
pod install
```

### Bước 3: Mở dự án

Mở file workspace của dự án (KHÔNG mở file .xcodeproj):

```bash
open SosMienTrung.xcworkspace
```

### Bước 4: Chạy ứng dụng

Chọn Simulator (ví dụ: iPhone 15) hoặc thiết bị thật và nhấn `Cmd + R` để khởi chạy.

## 3. Cấu hình hệ thống (System Configuration)

### Các thông số chính trong Info.plist

- `BASE_URL`: Địa chỉ API Backend (Mặc định: `http://192.168.1.144:8080` cho môi trường dev).
- `GIDClientID`: Client ID dùng cho đăng nhập Google.
- `RecaptchaSiteKey`: Key bảo mật dùng cho xác thực Recaptcha.

### Quyền truy cập hệ thống (Permissions)

Để đảm bảo tính năng cứu hộ hoạt động, ứng dụng yêu cầu các quyền:

- **NSLocationAlwaysAndWhenInUseUsageDescription**: Luôn truy cập vị trí để gửi tọa độ cứu hộ.
- **NSBluetoothAlwaysUsageDescription**: Sử dụng Bluetooth để kết nối Mesh Network (Bridgefy) khi mất mạng.
- **NSCameraUsageDescription**: Dùng cho hiển thị chỉ dẫn AR.
- **NSMicrophoneUsageDescription**: Tiếp nhận yêu cầu SOS bằng giọng nói.

## 4. Tài khoản Demo (Demo Accounts)

Dưới đây là thông tin tài khoản dùng cho mục đích kiểm thử trên ứng dụng di động:

| Role        | Phone/Email        | Password    | Ghi chú                      |
| :---------- | :----------------- | :---------- | :--------------------------- |
| **Victim**  | 0374745872         | 142200      | Người dân gửi yêu cầu cứu hộ |
| **Rescuer** | rescuer109@resq.vn | Rescuer@123 | Đội ngũ cứu hộ thực địa      |

## 5. Cấu trúc Source Code

- `/SosMienTrung`: Chứa toàn bộ mã nguồn chính của ứng dụng.
  - `/App`: Điểm khởi đầu ứng dụng và cấu hình TabBar.
  - `/Views`: Các màn hình giao diện (Dashboard, SOS, Maps, Profile).
  - `/ViewModels`: Xử lý logic nghiệp vụ và dữ liệu cho các View.
  - `/Models`: Định nghĩa các thực thể dữ liệu (SOS Request, User, Chat).
  - `/Persistence`: Cấu hình Core Data lưu trữ offline.
  - `/Utilities`: Các hàm hỗ trợ (Keychain, LocationManager, MeshHelper).
- `/SosMienTrungTests`: Các kịch bản kiểm thử Unit Test.
- `/Pods`: Các thư viện bên thứ 3 được quản lý bởi CocoaPods.

---

_Dự án thuộc Bộ môn Kỹ thuật phần mềm - Capstone Project submission._
