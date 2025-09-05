# USDC Wallet - White-Label Solution

A customizable, white-label mobile wallet application for USDC on Base blockchain.

## Features

- **Wallet Management**: Create/import wallets with BIP39 mnemonics
- **USDC Operations**: Send/receive USDC with gas sponsorship
- **Fiat Conversion**: Real-time balance conversion to multiple currencies
- **White-Label**: Customizable branding, colors, and themes
- **Gas Sponsorship**: Optional gas fee coverage via relayer

## Configuration

Edit `lib/config/app_config.dart` to customize:
- App name and branding
- Colors and themes
- Feature flags
- Network settings

## Getting Started

```bash
flutter pub get
flutter run
```

## Network

Currently configured for Base Sepolia Testnet:
- Chain ID: 84532
- USDC Contract: 0x036CbD53842c5426634e7929541eC2318f3dCF7e

## Account Abstraction (AA) via Biconomy

This project is configured to use Biconomy for gasless USDC transfers via smart accounts. The legacy in-house gas sponsorship endpoints have been removed.

Backend required environment variables:

```
JWT_SECRET=change-me
RPC_URL=https://sepolia.base.org
CHAIN_ID=84532
USDC_CONTRACT_ADDRESS=0x036CbD53842c5426634e7929541eC2318f3dCF7e

# Biconomy
BICONOMY_BUNDLER_URL=...        # from Biconomy dashboard
BICONOMY_PAYMASTER_URL=...      # from Biconomy dashboard
# Optional override; defaults to v0.6
ENTRY_POINT_ADDRESS=0x0000000071727De22E5E9d8BAf0edAc6f37da032
```

Endpoints:
- `GET /v1/wallet/aa-address` → returns the smart account address (creates via Biconomy if not present)
- `POST /v1/wallet/send-aa { to, amount }` → sends USDC using AA with Biconomy paymaster

Flutter app now always uses the AA path in WaaS mode.

## QR Scanner and Push Notifications

QR scanning:
- Added `mobile_scanner`. The QR icon in Send screen opens a scanner and fills the address.
- Requires camera permission (already set for Android and iOS).

Notifications:
- Local notifications via `flutter_local_notifications`.
- Optional FCM via `firebase_core` and `firebase_messaging`.
- To enable FCM:
  1. Add `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist` from Firebase Console.
  2. Integrate the Firebase Gradle plugin and iOS plist steps per FlutterFire docs.
  3. App initializes notifications automatically on startup.# waas-wallet
# waas-wallet
