//
//  AppearanceCustomizationView.swift
//  SosMienTrung
//
//  Màn hình tùy chỉnh giao diện
//

import SwiftUI

struct AppearanceCustomizationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appearanceManager = AppearanceManager.shared
    
    @State private var selectedTab = 0
    @State private var tempPattern: BackgroundPattern
    @State private var tempOpacity: Double
    @State private var tempScale: Double
    @State private var tempColor: Color
    @State private var tempUseGradient: Bool
    @State private var tempGradientEndColor: Color
    
    init() {
        let manager = AppearanceManager.shared
        _tempPattern = State(initialValue: manager.selectedPattern)
        _tempOpacity = State(initialValue: manager.patternOpacity)
        _tempScale = State(initialValue: manager.patternScale)
        _tempColor = State(initialValue: Color(hex: manager.backgroundColorHex))
        _tempUseGradient = State(initialValue: manager.useGradient)
        _tempGradientEndColor = State(initialValue: Color(hex: manager.gradientEndColorHex))
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Preview area
                previewArea
                    .frame(height: geometry.size.height * 0.45)
                
                // Tab selector
                tabSelector
                
                // Content based on tab
                ScrollView {
                    switch selectedTab {
                    case 0:
                        patternSelectionView
                    case 1:
                        colorSelectionView
                    default:
                        EmptyView()
                    }
                }
                .frame(maxHeight: .infinity)
                
                // Bottom buttons
                bottomButtons
            }
            .background(Color(UIColor.systemGroupedBackground))
        }
    }
    
    // MARK: - Preview Area
    private var previewArea: some View {
        ZStack {
            // Background color/gradient
            if tempUseGradient {
                LinearGradient(
                    colors: [tempColor, tempGradientEndColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                tempColor
            }
            
            // Pattern overlay using ImagePaint
            if tempPattern != .none {
                Rectangle()
                    .fill(
                        ImagePaint(
                            image: Image(tempPattern.rawValue),
                            scale: tempScale
                        )
                    )
                    .opacity(tempOpacity)
            }
            
            // Sample messages
            VStack(spacing: 12) {
                // Received message
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Người cứu hộ")
                            .font(.caption.bold())
                            .foregroundColor(.blue)
                        Text("Xin chào, bạn cần hỗ trợ gì? 👋")
                            .foregroundColor(.primary)
                        Text("02:20")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding(12)
                    .background(Color(UIColor.systemBackground).opacity(0.95))
                    .cornerRadius(16)
                    .frame(maxWidth: 250, alignment: .leading)
                    
                    Spacer()
                }
                
                // Sent message
                HStack {
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Tôi đang bị kẹt ở đây, cần cứu hộ! 🆘")
                            .foregroundColor(.white)
                        HStack(spacing: 4) {
                            Text("02:21")
                                .font(.caption2)
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                        }
                        .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(12)
                    .background(Color.blue)
                    .cornerRadius(16)
                    .frame(maxWidth: 250, alignment: .trailing)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton(title: "Nền", icon: "photo.fill", index: 0)
            tabButton(title: "Màu", icon: "paintpalette.fill", index: 1)
        }
        .padding(4)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(10)
        .padding()
    }
    
    private func tabButton(title: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(selectedTab == index ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedTab == index ? Color.green : Color.clear)
            )
        }
    }
    
    // MARK: - Pattern Selection View
    private var patternSelectionView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Pattern grid
            VStack(alignment: .leading, spacing: 12) {
                Text("Chọn hoạ tiết")
                    .font(.headline)
                    .padding(.horizontal)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(BackgroundPattern.allCases) { pattern in
                        patternThumbnail(pattern)
                    }
                }
                .padding(.horizontal)
            }
            
            // Opacity slider
            if tempPattern != .none {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cường độ")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    HStack {
                        Image(systemName: "circle")
                            .foregroundColor(.gray)
                        
                        Slider(value: $tempOpacity, in: 0.05...0.8)
                            .tint(.blue)
                        
                        Image(systemName: "circle.fill")
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    
                    Text("Độ hiển thị: \(Int(tempOpacity * 100))%")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                }
                
                // Scale slider
                VStack(alignment: .leading, spacing: 12) {
                    Text("Kích thước")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    HStack {
                        Image(systemName: "minus.magnifyingglass")
                            .foregroundColor(.gray)
                        
                        Slider(value: $tempScale, in: 0.2...1.0)
                            .tint(.green)
                        
                        Image(systemName: "plus.magnifyingglass")
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    
                    Text("Tỉ lệ: \(Int(tempScale * 100))%")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                }
            }
            
            Spacer(minLength: 20)
        }
        .padding(.top)
    }
    
    private func patternThumbnail(_ pattern: BackgroundPattern) -> some View {
        Button {
            withAnimation {
                tempPattern = pattern
            }
        } label: {
            ZStack {
                if pattern == .none {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(tempColor)
                        .frame(height: 80)
                    
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.5))
                } else {
                    ZStack {
                        tempColor
                        
                        Rectangle()
                            .fill(
                                ImagePaint(
                                    image: Image(pattern.rawValue),
                                    scale: 0.3
                                )
                            )
                            .opacity(0.4)
                    }
                    .frame(height: 80)
                    .cornerRadius(12)
                }
                
                // Selection indicator
                if tempPattern == pattern {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green, lineWidth: 3)
                        .frame(height: 80)
                    
                    Circle()
                        .fill(Color.green)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        )
                }
            }
        }
    }
    
    // MARK: - Color Selection View
    private var colorSelectionView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Main Color Picker
            VStack(alignment: .leading, spacing: 12) {
                Text("Chọn màu nền")
                    .font(.headline)
                    .padding(.horizontal)
                
                ColorPicker("Màu nền chính", selection: $tempColor, supportsOpacity: false)
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
            
            // Gradient toggle
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $tempUseGradient) {
                    HStack {
                        Image(systemName: "square.stack.3d.up.fill")
                            .foregroundColor(.purple)
                        Text("Sử dụng gradient")
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                
                if tempUseGradient {
                    ColorPicker("Màu gradient thứ 2", selection: $tempGradientEndColor, supportsOpacity: false)
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
            }
            
            Spacer(minLength: 20)
        }
        .padding(.top)
    }
    
    // MARK: - Bottom Buttons
    private var bottomButtons: some View {
        HStack(spacing: 0) {
            Button {
                dismiss()
            } label: {
                Text("Bỏ")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            
            Divider()
                .frame(height: 50)
            
            Button {
                applyChanges()
                dismiss()
            } label: {
                Text("Áp dụng")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
    }
    
    private func applyChanges() {
        appearanceManager.selectedPattern = tempPattern
        appearanceManager.patternOpacity = tempOpacity
        appearanceManager.patternScale = tempScale
        appearanceManager.backgroundColorHex = tempColor.toHex()
        appearanceManager.useGradient = tempUseGradient
        appearanceManager.gradientEndColorHex = tempGradientEndColor.toHex()
    }
}

// MARK: - Color to Hex Extension
extension Color {
    func toHex() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        
        return String(format: "%02X%02X%02X", r, g, b)
    }
}

#Preview {
    AppearanceCustomizationView()
}
