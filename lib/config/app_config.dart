import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Configuration class for white-label customization
class AppConfig {
  // App branding
  static const String appName = 'USDC Wallet';
  static const String appVersion = '1.0.0';
  
  // Company information
  static const String companyName = 'Your Company Name';
  static const String companyWebsite = 'https://yourcompany.com';
  static const String supportEmail = 'support@yourcompany.com';
  
  // App colors and theme - Professional & Modern
  static const Color primaryColor = Color(0xFF0052FF); // Primary Blue
  static const Color secondaryColor = Color(0xFF6366F1); // Secondary Purple
  static const Color accentColor = Color(0xFF10B981); // Accent Green
  
  // Dark Mode Colors Only
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkCard = Color(0xFF334155);
  static const Color darkText = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkBorder = Color(0xFF475569);
  static const Color darkDivider = Color(0xFF334155);
  
  // Status Colors
  static const Color successColor = Color(0xFF10B981); // Green
  static const Color errorColor = Color(0xFFEF4444); // Red
  static const Color warningColor = Color(0xFFF59E0B); // Orange
  static const Color infoColor = Color(0xFF3B82F6); // Blue
  
  // Gradient Colors
  static const Color gradientStart = Color(0xFF0052FF);
  static const Color gradientMiddle = Color(0xFF6366F1);
  static const Color gradientEnd = Color(0xFF8B5CF6);
  
  // Logo and branding assets
  static const String logoPath = 'assets/images/logo.png';
  static const String logoDarkPath = 'assets/images/logo_dark.png';
  static const String faviconPath = 'assets/images/favicon.png';
  
  // Feature flags
  static const bool enableGasSponsorship = true;
  static const bool enableFiatConversion = true;
  static const bool enablePushNotifications = true;
  static const bool enableBiometricAuth = true;
  static const bool enableSocialLogin = false; // WaaS feature
  
  // WaaS configuration
  static const bool enableWaaS = true; // Toggle WaaS mode
  static const String waasApiBaseUrl = 'http://localhost:4000';
  static const String waasApiKey = '';
  static const String waasAuthEndpoint = '/v1/auth';
  static const String waasWalletEndpoint = '/v1/wallet';

  // Resolve API base URL depending on runtime platform
  static String get apiBaseUrl {
    if (kIsWeb) return waasApiBaseUrl;
    try {
      if (Platform.isAndroid) {
        // Android emulator's alias to host loopback
        return 'http://10.0.2.2:4000';
      }
    } catch (_) {
      // Platform may not be available in some contexts; fall back
    }
    return waasApiBaseUrl;
  }
  
  // Network configuration
  static const String networkName = 'Base Sepolia Testnet';
  static const String networkChainId = '84532';
  static const String networkExplorer = 'https://sepolia.basescan.org';
  
  // USDC configuration
  static const String usdcContractAddress = '0x036CbD53842c5426634e7929541eC2318f3dCF7e';
  static const int usdcDecimals = 6;
  static const String usdcSymbol = 'USDC';
  
  // Gas configuration
  static const String baseGasStationUrl = 'https://gasstation.base.org';
  static const String biconomyUrl = 'https://api.biconomy.io';
  static const String gelatoUrl = 'https://relay.gelato.digital';
  static const int defaultGasLimit = 100000;
  static const double defaultGasPrice = 20.0; // Gwei
  static const bool enableRelayerFallback = true;
  
  // UI configuration
  static const double borderRadius = 12.0;
  static const double cardElevation = 4.0;
  static const Duration animationDuration = Duration(milliseconds: 300);
  
  // Security configuration
  static const int mnemonicWordCount = 12;
  static const bool enablePrivateKeyExport = false;
  static const bool enableAddressBook = true;
  
  // Notification configuration
  static const String pushNotificationTitle = 'USDC Wallet';
  static const String pushNotificationBody = 'You have received USDC!';
  
  // Get theme data for dark mode only
  static ThemeData getDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.blue,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: darkBackground,
      cardColor: darkCard,
      dividerColor: darkDivider,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: darkText),
        bodyMedium: TextStyle(color: darkText),
        titleLarge: TextStyle(color: darkText),
        titleMedium: TextStyle(color: darkText),
        labelLarge: TextStyle(color: darkText),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkText,
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: primaryColor.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 28),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 28),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: darkSurface,
        labelStyle: const TextStyle(color: darkTextSecondary),
        hintStyle: const TextStyle(color: darkTextSecondary),
      ),
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: darkSurface,
        background: darkBackground,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: darkText,
        onBackground: darkText,
      ),
    );
  }

  // Get theme data (defaults to dark mode)
  static ThemeData getThemeData() {
    return getDarkTheme();
  }
  
  // Get app information
  static Map<String, dynamic> getAppInfo() {
    return {
      'name': appName,
      'version': appVersion,
      'company': companyName,
      'website': companyWebsite,
      'support': supportEmail,
      'network': networkName,
      'chainId': networkChainId,
      'usdcContract': usdcContractAddress,
    };
  }
}
