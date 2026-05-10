# ResQ SOS iOS App - Capstone Project

<div align="center">
  <br />
    <a href="/" target="_blank">
      <img src="https://res.cloudinary.com/dpqvdxj10/image/upload/v1778384162/52e64225-6db4-4906-9453-32fa3123a42e_iwsqtc.jpg" alt="Project Banner">
    </a>
  <br />

  <div>
<img src="https://img.shields.io/badge/-Swift-F05138?style=for-the-badge&logo=Swift&logoColor=white" />
<img src="https://img.shields.io/badge/-SwiftUI-0072C6?style=for-the-badge&logo=Swift&logoColor=white" />
<img src="https://img.shields.io/badge/-Firebase-FFCA28?style=for-the-badge&logo=Firebase&logoColor=black" />
<img src="https://img.shields.io/badge/-CoreLocation-34C759?style=for-the-badge&logo=Apple&logoColor=white" /><br/>
<img src="https://img.shields.io/badge/-Bridgefy-1D1D1D?style=for-the-badge&logoColor=white" />
<img src="https://img.shields.io/badge/-CoreData-0052CC?style=for-the-badge&logo=Apple&logoColor=white" />
<img src="https://img.shields.io/badge/-CocoaPods-EE3322?style=for-the-badge&logo=CocoaPods&logoColor=white" />
  </div>

  <h3 align="center">RES-Q | Intelligent System for SOS Triage and Disaster Resource Allocation</h3>

</div>

Emergency Rescue and Disaster Coordination System (RES-Q) — iOS Mobile Application.

## 📋 <a name="table">Table of Contents</a>

1. ✨ [Introduction](#introduction)
2. ⚙️ [Tech Stack](#tech-stack)
3. 🔋 [Features](#features)
4. 🤸 [Quick Start](#quick-start)

## <a name="introduction">✨ Introduction</a>

iOS emergency rescue platform built with Swift and Firebase — designed to operate even when internet connectivity is unavailable. RES-Q enables victims to send SOS requests with real-time GPS coordinates, while rescue coordinators triage, dispatch, and track missions from a centralized dashboard. Peer-to-peer offline communication is powered by Bridgefy's Bluetooth mesh network, ensuring the system remains functional in disaster scenarios where infrastructure fails.

## <a name="tech-stack">⚙️ Tech Stack</a>

- **[Swift 5.10](https://swift.org/)** is the primary language used across the entire application, offering type safety and modern concurrency support for a reliable rescue-critical system.

- **[SwiftUI](https://developer.apple.com/xcode/swiftui/)** is Apple's declarative UI framework used to build all screens — from SOS submission to the coordinator dashboard — with reactive data binding.

- **[Bridgefy SDK](https://bridgefy.me/)** enables offline peer-to-peer mesh communication over Bluetooth and WiFi Direct, allowing users to send and receive SOS messages without any internet connection.

- **[Firebase](https://firebase.google.com/)** provides the cloud backend including Authentication for secure login, Cloud Messaging (FCM) for push notifications, and Analytics for usage monitoring.

- **[Google Sign-In & Recaptcha Enterprise](https://developers.google.com/identity)** handle secure user authentication and bot protection at the system boundary.

- **[CoreLocation & Apple Maps](https://developer.apple.com/documentation/corelocation)** power continuous GPS tracking, enabling victims to share precise coordinates and coordinators to visualize field positions in real time.

- **[Core Data](https://developer.apple.com/documentation/coredata)** persists SOS requests locally on-device so no data is lost when the app operates fully offline.

- **[CocoaPods](https://cocoapods.org/)** manages all third-party dependencies across the project.

## <a name="features">🔋 Features</a>

👉 **SOS Request Submission**: Victims can send a distress signal with a single tap, automatically attaching their GPS coordinates and severity level for rapid triage.

👉 **Offline Mesh Communication**: Bridgefy SDK enables device-to-device messaging over Bluetooth/WiFi Direct — no internet required — ensuring connectivity in disaster zones.

👉 **Real-Time GPS Tracking**: Continuous location updates via CoreLocation allow coordinators to monitor victim and rescuer positions on a live map.

👉 **Rescue Coordinator Dashboard**: A dedicated interface for coordinators to view incoming SOS requests, assign rescuers, and track mission progress in real time.

👉 **Offline-First Persistence**: Core Data stores all SOS data locally, syncing with the backend once connectivity is restored — zero data loss guaranteed.

👉 **Push Notifications**: Firebase Cloud Messaging delivers instant alerts to rescuers when a new SOS is assigned or a mission status changes.

👉 **Role-Based Access**: Separate flows for victims, rescuers, and coordinators with appropriate permissions and UI tailored to each role.

👉 **In-App Messaging**: Real-time chat between victims and rescue teams to coordinate during active missions.

And many more, including secure Keychain storage and AR-assisted navigation guidance.

## <a name="quick-start">🤸 Quick Start</a>

Follow these steps to set up the project locally on your machine.

**Prerequisites**

Make sure you have the following installed:

- macOS with **Xcode 15.0+**
- **CocoaPods**

**Install CocoaPods** (if not already installed)

```bash
sudo gem install cocoapods
```

**Clone the Repository**

```bash
git clone <your-repo-url>
cd resq-sos-mientrung-ios
```

**Install Dependencies**

```bash
pod install
```

**Open the Workspace**

```bash
open SosMienTrung.xcworkspace
```

**Configure `Info.plist`**

Set the following keys before running:

```
BASE_URL        → Your backend API URL (e.g. http://192.168.1.144:8080)
GIDClientID     → Your Google Sign-In client ID
RecaptchaSiteKey → Your Recaptcha Enterprise site key
```

**Run the App**

Select a Simulator (e.g. iPhone 15) or a physical device and press `Cmd + R`.

---

_A Software Engineering capstone project submission._
