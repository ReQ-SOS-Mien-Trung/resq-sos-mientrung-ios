//
//  HeadingManager.swift
//  SosMienTrung
//
//  Quản lý hướng la bàn (compass heading) từ CLLocationManager
//

import Foundation
import CoreLocation
import Combine
import simd

final class HeadingManager: NSObject, ObservableObject {
    @Published var heading: CLHeading?
    @Published var trueHeading: Double = 0
    @Published var magneticHeading: Double = 0
    @Published var headingAccuracy: Double = -1
    @Published var isHeadingAvailable: Bool = false

    private let locationManager = CLLocationManager()
    private var lastUpdateTime: Date = Date()
    private let minimumUpdateInterval: TimeInterval = 0.05 // 20 FPS max cho heading

    override init() {
        super.init()
        locationManager.delegate = self
        isHeadingAvailable = CLLocationManager.headingAvailable()
    }

    func startUpdatingHeading() {
        guard CLLocationManager.headingAvailable() else {
            print("⚠️ Heading not available on this device")
            isHeadingAvailable = false
            return
        }

        isHeadingAvailable = true
        locationManager.headingFilter = 1 // Cập nhật khi thay đổi 1 độ
        locationManager.headingOrientation = .portrait
        locationManager.startUpdatingHeading()
        print("🧭 Started heading updates")
    }

    func stopUpdatingHeading() {
        locationManager.stopUpdatingHeading()
        print("🧭 Stopped heading updates")
    }

    /// Chuyển đổi hướng tương đối từ NearbyInteraction thành hướng tuyệt đối
    /// - Parameters:
    ///   - relativeDirection: Vector hướng từ NI (tương đối so với thiết bị)
    ///   - Returns: Góc tuyệt đối (0-360, 0 = Bắc)
    func absoluteBearing(from relativeDirection: simd_float3) -> Double {
        // Tính góc tương đối từ vector direction
        // X: phải (+) / trái (-)
        // Z: trước (-) / sau (+) - lưu ý NI dùng hệ tọa độ khác
        let relativeAngle = atan2(Double(relativeDirection.x), Double(-relativeDirection.z))
        let relativeAngleDegrees = relativeAngle * 180.0 / .pi

        // Kết hợp với true heading để có hướng tuyệt đối
        let absoluteAngle = trueHeading + relativeAngleDegrees

        // Normalize về 0-360
        return normalizeAngle(absoluteAngle)
    }

    /// Tính góc mà mũi tên cần xoay để chỉ đến peer
    /// - Parameters:
    ///   - relativeDirection: Vector hướng từ NI
    /// - Returns: Góc xoay cho mũi tên UI (0 = hướng lên màn hình)
    func arrowRotation(from relativeDirection: simd_float3) -> Double {
        // Vector direction từ NI đã là tương đối so với thiết bị
        // Chỉ cần project lên mặt phẳng ngang và tính góc
        let x = Double(relativeDirection.x)
        let z = Double(relativeDirection.z)

        // atan2(x, -z) cho góc từ hướng "về phía trước" (-Z) quay sang phải (+X)
        let radians = atan2(x, -z)
        let degrees = radians * 180.0 / .pi

        return degrees
    }

    private func normalizeAngle(_ angle: Double) -> Double {
        var result = angle.truncatingRemainder(dividingBy: 360)
        if result < 0 {
            result += 360
        }
        return result
    }
}

extension HeadingManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Debouncing
        let now = Date()
        guard now.timeIntervalSince(lastUpdateTime) >= minimumUpdateInterval else { return }
        lastUpdateTime = now

        DispatchQueue.main.async {
            self.heading = newHeading
            self.trueHeading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
            self.magneticHeading = newHeading.magneticHeading
            self.headingAccuracy = newHeading.headingAccuracy
        }
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        // Hiển thị UI calibration nếu độ chính xác thấp
        return headingAccuracy < 0 || headingAccuracy > 25
    }
}
