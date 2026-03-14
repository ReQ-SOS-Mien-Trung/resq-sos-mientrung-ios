//
//  FindingMode.swift
//  SosMienTrung
//
//  Defines the two finding modes for AR visualization.
//

import Foundation

/// Vai trò của người dùng trong phiên Nearby Interaction
enum UserRole {
    /// Người cứu hộ — chủ động tìm victim, hiển thị AR overlay
    case rescuer
    /// Nạn nhân — cần được tìm, chỉ broadcast vị trí / NI token, không hiển thị camera AR
    case victim
}

enum FindingMode {
    case exhibit      // Multiple animated spheres (Apple sample – không dùng trong app này)
    case rescuer      // Text banner + sphere dưới góc nhìn người cứu hộ tìm victim

    // Backward compat alias
    static var visitor: FindingMode { .rescuer }
}
