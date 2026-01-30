import SwiftUI

// Legacy SOSFormView - redirect to new Wizard
struct SOSFormView: View {
    @ObservedObject var bridgefyManager: BridgefyNetworkManager
    
    var body: some View {
        // Use new Wizard view
        SOSWizardView(bridgefyManager: bridgefyManager)
    }
}

#Preview {
    SOSFormView(bridgefyManager: BridgefyNetworkManager.shared)
}
