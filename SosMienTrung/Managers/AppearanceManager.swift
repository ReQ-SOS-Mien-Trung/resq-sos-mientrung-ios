//
//  AppearanceManager.swift
//  SosMienTrung
//
//  Simplified appearance — delegates to DS design tokens.
//

import SwiftUI
import Combine

// MARK: - Background Pattern (kept for backward compat)
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

// MARK: - Preset Colors (kept for backward compat)
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

// MARK: - Appearance Manager (Simplified)
@MainActor
final class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()

    @Published var batterySavingMode: Bool {
        didSet {
            UserDefaults.standard.set(batterySavingMode, forKey: "batterySavingMode")
        }
    }

    /// True when user selected "Tối" in theme picker
    @Published var isDarkTheme: Bool = false

    /// True when user selected "Sáng" in theme picker (forces light regardless of system)
    @Published var isLightThemeForced: Bool = false

    /// Drives DS.Colors (legacy — colors are now adaptive so this is only used for computedColorScheme)
    var shouldUseDarkColors: Bool {
        batterySavingMode || isDarkTheme
    }

    /// The `preferredColorScheme` to apply at the root view.
    /// DS.Colors use adaptive UIColor providers, so they respond to whatever scheme is active.
    var computedColorScheme: ColorScheme? {
        if isLightThemeForced { return .light }
        if batterySavingMode || isDarkTheme { return .dark }
        return nil   // follow system — adaptive colors handle dark/light automatically
    }

    // MARK: - Compat properties → DS tokens
    var textColor: Color { DS.Colors.text }
    var secondaryTextColor: Color { DS.Colors.textSecondary }
    var tertiaryTextColor: Color { DS.Colors.textMuted }
    var sectionBackgroundColor: Color { DS.Colors.surface }
    var iconTintColor: Color { DS.Colors.textSecondary }
    var backgroundColor: Color { DS.Colors.background }
    var gradientEndColor: Color { DS.Colors.background }

    // Kept for backward compat — views that reference these won't crash
    @Published var selectedPattern: BackgroundPattern = .none
    @Published var patternOpacity: Double = 0
    @Published var patternScale: Double = 0.5
    @Published var backgroundColorHex: String = "FFFFFF"
    @Published var useGradient: Bool = false
    @Published var gradientEndColorHex: String = "E0E0E0"

    private init() {
        self.batterySavingMode = UserDefaults.standard.bool(forKey: "batterySavingMode")
        let themeRaw = UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.system.rawValue
        let savedTheme = AppTheme(rawValue: themeRaw) ?? .system
        self.isDarkTheme = (savedTheme == .dark)
        self.isLightThemeForced = (savedTheme == .light)
    }

    func apply(theme: AppTheme, batterySavingMode: Bool) {
        if self.batterySavingMode != batterySavingMode {
            self.batterySavingMode = batterySavingMode
        }

        let shouldUseDarkTheme = theme == .dark
        if isDarkTheme != shouldUseDarkTheme {
            isDarkTheme = shouldUseDarkTheme
        }

        let shouldForceLightTheme = theme == .light
        if isLightThemeForced != shouldForceLightTheme {
            isLightThemeForced = shouldForceLightTheme
        }
    }

    func resetToDefaults() {
        batterySavingMode = false
    }

    func toggleBatterySavingMode() {
        batterySavingMode.toggle()
    }
}
