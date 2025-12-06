import UIKit
import BridgefySDK

class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private var bridgefy: Bridgefy?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        do {
            let bridgefy = try Bridgefy(withApiKey: "5a369f96-13d3-40df-8d41-805bf150cac0", delegate: self, verboseLogging: false)
            self.bridgefy = bridgefy
            bridgefy.start()
            print("Bridgefy started")
        } catch {
            print("Bridgefy failed to initialize: \(error.localizedDescription)")
        }
        return true
    }
}

// MARK: - BridgefyDelegate

extension AppDelegate: BridgefyDelegate {
    func bridgefyDidStart(with userId: UUID) {
        print("Bridgefy did start with userId: \(userId)")
    }

    func bridgefyDidFailToStart(with error: BridgefyError) {
        print("Bridgefy failed to start: \(error)")
    }

    func bridgefyDidStop() {
        print("Bridgefy did stop")
    }

    func bridgefyDidFailToStop(with error: BridgefyError) {
        print("Bridgefy failed to stop: \(error)")
    }

    func bridgefyDidDestroySession() {
        print("Bridgefy destroyed session")
    }

    func bridgefyDidFailToDestroySession(with error: BridgefyError) {
        print("Bridgefy failed to destroy session: \(error)")
    }

    func bridgefyDidConnect(with userId: UUID) {
        print("Connected with: \(userId)")
    }

    func bridgefyDidDisconnect(from userId: UUID) {
        print("Disconnected from: \(userId)")
    }

    func bridgefyDidEstablishSecureConnection(with userId: UUID) {
        print("Secure connection established with: \(userId)")
    }

    func bridgefyDidFailToEstablishSecureConnection(with userId: UUID, error: BridgefyError) {
        print("Failed to establish secure connection with \(userId): \(error)")
    }

    func bridgefyDidSendMessage(with messageId: UUID) {
        print("Message sent: \(messageId)")
    }

    func bridgefyDidFailSendingMessage(with messageId: UUID, withError error: BridgefyError) {
        print("Failed to send message \(messageId): \(error)")
    }

    func bridgefyDidReceiveData(_ data: Data, with messageId: UUID, using transmissionMode: TransmissionMode) {
        let text = String(data: data, encoding: .utf8) ?? "<binary>"
        print("Received message \(messageId) via \(transmissionMode): \(text)")
    }
}
