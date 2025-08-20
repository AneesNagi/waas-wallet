# USDC Wallet App

A modern, responsive mobile wallet application for sending and receiving USDC tokens on the Base Network. Built with Flutter and designed for white-label Wallet as a Service (WaaS) projects.

## Features

- **Dashboard**: View USDC balance and recent transactions
- **Send USDC**: Send USDC to any wallet address with confirmation dialogs
- **Receive USDC**: Generate QR codes and share wallet addresses
- **Transaction History**: View all transactions with filtering options
- **Settings**: Comprehensive wallet configuration and security options
- **Responsive Design**: Optimized for all mobile screen sizes
- **Dark Theme**: Modern dark UI with blue accent colors

## Screenshots

The app includes the following main screens:
- Dashboard with balance overview
- Send USDC interface
- Receive USDC with QR code
- Transaction history
- Settings and configuration

## Tech Stack

- **Framework**: Flutter 3.0+
- **Language**: Dart
- **State Management**: Provider
- **UI Components**: Material Design 3
- **Responsive Design**: flutter_screenutil
- **QR Code Generation**: qr_flutter
- **Clipboard Operations**: clipboard
- **Typography**: Google Fonts (Inter)

## Prerequisites

- Flutter SDK 3.0 or higher
- Dart SDK 2.17 or higher
- Android Studio / VS Code with Flutter extensions
- Android SDK (for Android development)
- Xcode (for iOS development, macOS only)

## Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd usdc_wallet
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── screens/                  # Screen implementations
│   ├── home_screen.dart     # Main navigation container
│   ├── dashboard_screen.dart # Dashboard with balance overview
│   ├── send_screen.dart     # Send USDC interface
│   ├── receive_screen.dart  # Receive USDC with QR code
│   ├── transaction_history_screen.dart # Transaction list
│   └── settings_screen.dart # Settings and configuration
└── assets/
    ├── images/              # Image assets
    └── icons/               # Icon assets
```

## Configuration

### Network Configuration
The app is configured for Base Network (Ethereum L2). To change networks:

1. Update the network configuration in `settings_screen.dart`
2. Modify RPC endpoints and chain IDs
3. Update USDC contract addresses for different networks

### Theme Customization
The app uses a dark theme with blue accents. To customize:

1. Modify colors in `main.dart` ThemeData
2. Update accent colors throughout the app
3. Customize typography using Google Fonts

## Development

### Adding New Features
1. Create new screen files in `lib/screens/`
2. Add navigation in `home_screen.dart`
3. Update dependencies in `pubspec.yaml` if needed

### State Management
The app uses Provider for state management. To add new state:

1. Create provider classes for your data
2. Wrap widgets with ChangeNotifierProvider
3. Use Provider.of or Consumer widgets

### Responsive Design
The app uses `flutter_screenutil` for responsive design:

- Use `.w` for width dimensions
- Use `.h` for height dimensions
- Use `.sp` for font sizes
- Design size is set to iPhone X (375x812)

## Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/

# Run with coverage
flutter test --coverage
```

## Building for Production

### Android
```bash
flutter build apk --release
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

## Security Considerations

- **Private Keys**: Never store private keys in plain text
- **Biometric Auth**: Implement proper biometric authentication
- **Network Security**: Use HTTPS for all API calls
- **Input Validation**: Validate all user inputs
- **Secure Storage**: Use secure storage for sensitive data

## Future Enhancements

- [ ] Coinbase SDK integration for actual USDC transactions
- [ ] Multi-network support (Ethereum, Polygon, etc.)
- [ ] Push notifications for transactions
- [ ] Biometric authentication
- [ ] Multi-currency support
- [ ] Advanced security features
- [ ] Backup and recovery systems
- [ ] Analytics and reporting

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Create an issue in the repository
- Contact the development team
- Check the documentation

## Disclaimer

This is a frontend-only implementation. The actual wallet functionality, including private key management and blockchain transactions, needs to be implemented with proper security measures and the Coinbase SDK integration.
