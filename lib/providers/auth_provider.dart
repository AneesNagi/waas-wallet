import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/waas_service.dart';
import '../services/blockchain_service.dart';
import '../config/app_config.dart';

class AuthProvider extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final WaasService _waasService = WaasService();
  final BlockchainService _blockchainService = BlockchainService();

  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _walletAddress;
  String? _error;

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get walletAddress => _walletAddress;
  String? get error => _error;

  Future<void> initialize() async {
    if (!AppConfig.enableWaaS) return;
    _isLoading = true;
    notifyListeners();
    try {
      final token = await _secureStorage.read(key: 'waas_access_token');
      if (token != null && token.isNotEmpty) {
        _waasService.setAccessToken(token);
        try {
          final profile = await _waasService.getProfile();
          _walletAddress = profile['walletAddress'] as String?;
          if (_walletAddress != null) {
            await _blockchainService.initializeReadOnlyWallet(_walletAddress!);
            _isAuthenticated = true;
          }
        } catch (e) {
          // Bad/expired token or server unreachable: clear token and continue to sign-in
          await _secureStorage.delete(key: 'waas_access_token');
          _waasService.setAccessToken(null);
          _isAuthenticated = false;
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUp(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _waasService.signUp(email: email, password: password);
      final token = data['accessToken'] as String?;
      if (token != null) {
        await _secureStorage.write(key: 'waas_access_token', value: token);
        _waasService.setAccessToken(token);
      }
      _walletAddress = data['walletAddress'] as String?;
      if (_walletAddress != null) {
        await _blockchainService.initializeReadOnlyWallet(_walletAddress!);
      }
      _isAuthenticated = true;
    } catch (e) {
      if (e.toString().contains('email_exists')) {
        // Auto sign-in if account already exists
        try {
          final data = await _waasService.signIn(email: email, password: password);
          final token = data['accessToken'] as String?;
          if (token != null) {
            await _secureStorage.write(key: 'waas_access_token', value: token);
            _waasService.setAccessToken(token);
          }
          _walletAddress = data['walletAddress'] as String?;
          if (_walletAddress != null) {
            await _blockchainService.initializeReadOnlyWallet(_walletAddress!);
          }
          _isAuthenticated = true;
          _error = null;
        } catch (e2) {
          _error = 'An account already exists. Please sign in.';
        }
      } else {
        _error = e.toString();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _waasService.signIn(email: email, password: password);
      final token = data['accessToken'] as String?;
      if (token != null) {
        await _secureStorage.write(key: 'waas_access_token', value: token);
        _waasService.setAccessToken(token);
      }
      _walletAddress = data['walletAddress'] as String?;
      if (_walletAddress != null) {
        await _blockchainService.initializeReadOnlyWallet(_walletAddress!);
      }
      _isAuthenticated = true;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('unauthorized') || msg.contains('Invalid credentials')) {
        _error = 'Invalid email or password';
      } else if (msg.contains('account_requires_migration')) {
        _error = 'This account needs migration. Contact support to import your wallet.';
      } else {
        _error = msg;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _secureStorage.delete(key: 'waas_access_token');
    _waasService.setAccessToken(null);
    _walletAddress = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}


