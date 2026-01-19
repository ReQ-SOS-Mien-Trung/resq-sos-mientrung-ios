# Offline Account Handover Feature

## Overview

This feature enables users to transfer their account/identity from an old device to a new device under disaster conditions:

- **No Internet required** - Works completely offline
- **Disaster-safe** - Designed for emergency situations
- **Low battery support** - Emergency QR mode for dying devices
- **Secure** - Uses cryptographic signatures, never transmits passwords
- **Atomic** - Only one device can hold the identity at a time

## Architecture

### Core Principles

1. **Never transmit username/password** - Identity is cryptographic
2. **Don't clone Bridgefy Peer ID** - Each device gets its own Peer ID
3. **User identity is at application layer** - Bridgefy is just transport
4. **Identity = Cryptographic Key** - Represented by ECDSA key pair
5. **Single active device** - Only one device can be active at a time

### Files Created

| File                            | Purpose                                              |
| ------------------------------- | ---------------------------------------------------- |
| `IdentityKeyManager.swift`      | Secure Enclave key management, signing, verification |
| `UserIdentity.swift`            | Data models for identity, tokens, audit logs         |
| `IdentityHandoverManager.swift` | P2P handover logic using Multipeer Connectivity      |
| `IdentityHandoverView.swift`    | UI for normal and emergency handover flows           |

### Files Modified

| File                           | Changes                                        |
| ------------------------------ | ---------------------------------------------- |
| `User.swift`                   | Added identity linking, public key fingerprint |
| `BridgefyNetworkManager.swift` | Added identity mapping, takeover broadcasts    |
| `SettingsView.swift`           | Added handover and identity info options       |

## Data Models

### UserIdentity

```swift
struct UserIdentity {
    let id: String              // Unique user identifier
    var displayName: String
    var phoneNumber: String
    var role: UserRole          // civilian, rescuer, coordinator, admin
    var activeMissions: [String]
    var publicKeyData: Data     // User's public key
    var createdAt: Date
    var lastActiveAt: Date
}
```

### DelegationToken

```swift
struct DelegationToken {
    let tokenId: String
    let userIdentity: UserIdentity
    let issuedAt: Date
    let expiresAt: Date         // 5-15 minutes TTL
    let newDevicePublicKey: Data
    let oldDevicePublicKey: Data
    var signatureByOldDevice: Data?
    let nonce: String           // Prevent replay attacks
}
```

## Handover Flows

### Normal Mode (P2P)

```
┌──────────────┐                    ┌──────────────┐
│  Old Device  │                    │  New Device  │
└──────────────┘                    └──────────────┘
       │                                   │
       │ 1. Start Advertising              │
       │◄──────────────────────────────────│ Start Browsing
       │                                   │
       │ 2. Connection Established         │
       │◄─────────────────────────────────►│
       │                                   │
       │ 3. Receive Takeover Request       │
       │◄──────────────────────────────────│ Send Request
       │                                   │
       │ 4. User Confirms                  │
       │                                   │
       │ 5. Create & Sign Token            │
       │                                   │
       │ 6. Send Delegation Token          │
       │──────────────────────────────────►│ 7. Verify Token
       │                                   │
       │ 8. Revoke Identity               │ 9. Activate Identity
       │ (Destroy private key)            │
       │                                   │
       │ 10. Disable Bridgefy             │ 11. Broadcast Takeover
       │                                   │     to Mesh Network
       ▼                                   ▼
   [TRANSFERRED]                       [ACTIVE]
```

### Emergency Mode (QR Code)

For low battery situations:

1. Old device generates DelegationToken
2. Encode token as QR code
3. New device scans QR
4. New device verifies signature
5. Old device auto-revokes after QR generation

## Security Measures

### Token Security

- TTL: 5-15 minutes (shorter for low battery)
- One-time use only
- Signed with ECDSA/Secure Enclave
- Includes nonce to prevent replay

### Key Management

- Private keys stored in Secure Enclave (or Keychain on simulator)
- Keys never leave the device
- Private key destroyed on transfer

### Attack Prevention

- **Replay Attack**: Tokens tracked by ID, rejected if reused
- **Concurrent Takeover**: Only one transfer allowed at a time
- **Expiry Attack**: Strict TTL enforcement
- **Signature Forgery**: ECDSA verification required

## Bridgefy Integration

After successful handover:

1. New device joins mesh with its own Peer ID
2. Broadcasts `IdentityTakeoverBroadcast` to network
3. Other nodes update mapping: `userId → newPeerId`
4. Messages continue without interruption

## UI States

### SettingsView

- **Chuyển tài khoản** - Access handover feature
- **Danh tính số** - View identity info and audit logs

### IdentityHandoverView

- Role selection (send/receive)
- Peer discovery
- Connection status
- Progress indicators
- Success/failure states

### Emergency QR

- QR code display with timer
- QR scanner for new device

## Test Scenarios

1. ✅ Normal P2P transfer
2. ✅ Emergency QR transfer
3. ✅ Transfer with battery < 10%
4. ✅ Transfer while Bridgefy mesh active
5. ✅ Old device power loss mid-flow → No activation
6. ✅ Replay attack attempt → Rejected
7. ✅ Concurrent takeover attempts → Second rejected
8. ✅ Expired token → Rejected
9. ✅ New device joins mesh late → Receives broadcast

## Usage

### To Transfer Account (Old Device)

1. Go to Settings → Chuyển tài khoản
2. Select "Bắt đầu chuyển (P2P)" or "Tạo mã QR khẩn cấp"
3. Wait for new device to connect
4. Confirm the transfer request

### To Receive Account (New Device)

1. Go to Settings → Chuyển tài khoản
2. Select "Tìm thiết bị cũ (P2P)" or "Quét mã QR"
3. Select the old device from list
4. Wait for confirmation from old device

## API Reference

### IdentityKeyManager

```swift
// Generate key pair
try keyManager.generateIdentityKeyPair()

// Sign data
let signature = try keyManager.sign(data: data)

// Verify signature
let isValid = try keyManager.verify(signature: sig, data: data, publicKeyData: pubKey)

// Revoke identity (destroys private key)
try keyManager.revokeIdentity()
```

### IdentityHandoverManager

```swift
// Start as old device (sender)
handoverManager.startAsOldDevice()

// Start as new device (receiver)
handoverManager.startAsNewDevice()

// Approve/reject transfer request
handoverManager.approveTakeoverRequest()
handoverManager.rejectTakeoverRequest()

// Emergency QR
let qrString = try handoverManager.generateEmergencyQR()
try handoverManager.processEmergencyQR(qrString)
```

### BridgefyNetworkManager

```swift
// Broadcast identity takeover to mesh
bridgefyManager.broadcastIdentityTakeover(broadcast)

// Update identity mapping
bridgefyManager.updateIdentityMapping(userId: id, newPeerId: peerId)

// Get peer ID for user identity
let peerId = bridgefyManager.getPeerIdForIdentity(userId)
```

## Guarantees

- ✅ Bridgefy send/receive unaffected
- ✅ Peer ID change safe
- ✅ Identity transfer atomic
- ✅ Offline-first
- ✅ Disaster-safe
- ✅ Security-first
