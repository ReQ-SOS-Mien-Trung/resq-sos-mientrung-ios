//
//  TelegramBackground.swift
//  SosMienTrung
//
//  Unified background — ResQ Design System
//

import SwiftUI

struct TelegramBackground: View {
    var body: some View {
        DS.Colors.background
            .ignoresSafeArea()
    }
}

extension View {
    func telegramPatternBackground() -> some View {
        background(TelegramBackground())
    }
}
