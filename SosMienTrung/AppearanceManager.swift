//
//  AppearanceManager.swift
//  SosMienTrung
//
//  Quản lý giao diện ứng dụng
//

import SwiftUI
import Combine

// MARK: - Background Pattern
enum BackgroundPattern: String, CaseIterable, Identifiable {
    case pattern1 = "Telegram Chat Background Pattern 7"
    case pattern2 = "Telegram Chat Background Pattern 10"
    case pattern3 = "Telegram Chat Background Pattern 23"
    case none = "none"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .pattern1: return "Hoạ tiết 1"
        case .pattern2: return "Hoạ tiết 2"
        case .pattern3: return "Hoạ tiết 3"
        case .none: return "Không có"
        }
    }
}

// MARK: - Preset Colors
struct PresetColor: Identifiable {
    let id = UUID()
    let name: String
    let color: Color
    let hex: String
}

let presetColors: [PresetColor] = [
    PresetColor(name: "Xanh lá", color: Color(hex: "1B5E20"), hex: "1B5E20"),
    PresetColor(name: "Xanh dương", color: Color(hex: "0D47A1"), hex: "0D47A1"),
    PresetColor(name: "Tím", color: Color(hex: "4A148C"), hex: "4A148C"),
    PresetColor(name: "Hồng", color: Color(hex: "880E4F"), hex: "880E4F"),
    PresetColor(name: "Cam", color: Color(hex: "E65100"), hex: "E65100"),
    PresetColor(name: "Đỏ", color: Color(hex: "B71C1C"), hex: "B71C1C"),
    PresetColor(name: "Xám", color: Color(hex: "37474F"), hex: "37474F"),
    PresetColor(name: "Đen", color: Color(hex: "212121"), hex: "212121"),
    PresetColor(name: "Xanh ngọc", color: Color(hex: "004D40"), hex: "004D40"),
    PresetColor(name: "Nâu", color: Color(hex: "3E2723"), hex: "3E2723"),
    PresetColor(name: "Xanh navy", color: Color(hex: "1A237E"), hex: "1A237E"),
    PresetColor(name: "Gradient 1", color: Color(hex: "2E7D32"), hex: "2E7D32"),
]

// MARK: - Appearance Manager
class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()
    
    // Battery saving mode - synced with SettingsManager
    @Published var batterySavingMode: Bool {
        didSet {
            UserDefaults.standard.set(batterySavingMode, forKey: "batterySavingMode")
        }
    }
    
    // Pattern settings
    @Published var selectedPattern: BackgroundPattern {
        didSet {
            UserDefaults.standard.set(selectedPattern.rawValue, forKey: "backgroundPattern")
        }
    }
    
    @Published var patternOpacity: Double {
        didSet {
            UserDefaults.standard.set(patternOpacity, forKey: "patternOpacity")
        }
    }
    
    @Published var patternScale: Double {
        didSet {
            UserDefaults.standard.set(patternScale, forKey: "patternScale")
        }
    }
    
    // Background color settings
    @Published var backgroundColorHex: String {
        didSet {
            UserDefaults.standard.set(backgroundColorHex, forKey: "backgroundColorHex")
        }
    }
    
    @Published var useGradient: Bool {
        didSet {
            UserDefaults.standard.set(useGradient, forKey: "useGradient")
        }
    }
    
    @Published var gradientEndColorHex: String {
        didSet {
            UserDefaults.standard.set(gradientEndColorHex, forKey: "gradientEndColorHex")
        }
    }
    
    var backgroundColor: Color {
        if batterySavingMode {
            return .black
        }
        return Color(hex: backgroundColorHex)
    }
    
    var gradientEndColor: Color {
        if batterySavingMode {
            return .black
        }
        return Color(hex: gradientEndColorHex)
    }
    
    // MARK: - Adaptive Text Color
    /// Màu chữ thông minh dựa trên độ sáng của nền
    var textColor: Color {
        if batterySavingMode {
            return .white
        }
        let luminance = calculateLuminance(hex: backgroundColorHex)
        return luminance > 0.5 ? .black : .white
    }
    
    /// Màu chữ phụ (opacity thấp hơn)
    var secondaryTextColor: Color {
        if batterySavingMode {
            return Color.white.opacity(0.7)
        }
        let luminance = calculateLuminance(hex: backgroundColorHex)
        return luminance > 0.5 ? Color.black.opacity(0.7) : Color.white.opacity(0.7)
    }
    
    /// Màu chữ mờ
    var tertiaryTextColor: Color {
        if batterySavingMode {
            return Color.white.opacity(0.5)
        }
        let luminance = calculateLuminance(hex: backgroundColorHex)
        return luminance > 0.5 ? Color.black.opacity(0.5) : Color.white.opacity(0.5)
    }
    
    /// Màu nền cho section/card trong chế độ tiết kiệm pin
    var sectionBackgroundColor: Color {
        if batterySavingMode {
            return Color.white.opacity(0.1)
        }
        return Color.clear
    }
    
    /// Màu icon trong chế độ tiết kiệm pin
    var iconTintColor: Color {
        if batterySavingMode {
            return .gray
        }
        return .primary
    }
    
    /// Tính độ sáng (luminance) của màu theo công thức WCAG
    private func calculateLuminance(hex: String) -> Double {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        
        // Công thức tính luminance theo WCAG 2.0
        let rLinear = r <= 0.03928 ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4)
        let gLinear = g <= 0.03928 ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4)
        let bLinear = b <= 0.03928 ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4)
        
        return 0.2126 * rLinear + 0.7152 * gLinear + 0.0722 * bLinear
    }
    
    private init() {
        // Load saved settings
        self.batterySavingMode = UserDefaults.standard.bool(forKey: "batterySavingMode")
        
        let patternRaw = UserDefaults.standard.string(forKey: "backgroundPattern") ?? BackgroundPattern.pattern1.rawValue
        self.selectedPattern = BackgroundPattern(rawValue: patternRaw) ?? .pattern1
        
        self.patternOpacity = UserDefaults.standard.object(forKey: "patternOpacity") as? Double ?? 0.3
        self.patternScale = UserDefaults.standard.object(forKey: "patternScale") as? Double ?? 0.5
        
        self.backgroundColorHex = UserDefaults.standard.string(forKey: "backgroundColorHex") ?? "1B5E20"
        self.useGradient = UserDefaults.standard.bool(forKey: "useGradient")
        self.gradientEndColorHex = UserDefaults.standard.string(forKey: "gradientEndColorHex") ?? "004D40"
    }
    
    func resetToDefaults() {
        selectedPattern = .pattern1
        patternOpacity = 0.3
        patternScale = 0.5
        backgroundColorHex = "1B5E20"
        useGradient = false
        gradientEndColorHex = "004D40"
    }
    
    /// Toggle chế độ tiết kiệm pin
    func toggleBatterySavingMode() {
        batterySavingMode.toggle()
    }
}
