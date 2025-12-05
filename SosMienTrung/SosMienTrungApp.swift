//
//  SosMienTrungApp.swift
//  SosMienTrung
//
//  Created by Huỳnh Kim Cương on 6/12/25.
//

import SwiftUI
import CoreData

@main
struct SosMienTrungApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
