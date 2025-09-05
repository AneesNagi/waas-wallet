import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class WaasService {
  // Unauthorized broadcast for global handling
  static final StreamController<void> _unauthorizedController = StreamController<void>.broadcast();
  static Stream<void> get unauthorizedStream => _unauthorizedController.stream;
  static void notifyUnauthorized() {
    if (!_unauthorizedController.isClosed) {
      _unauthorizedController.add(null);
    }
  }

  final http.Client _httpClient = http.Client();
  static const Duration _timeout = Duration(seconds: 20);
  String? _accessToken;
  String? _custodialAddress;

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  String? get custodialAddress => _custodialAddress;

  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}${AppConfig.waasAuthEndpoint}/signup');
    final response = await _httpClient
        .post(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (AppConfig.waasApiKey.isNotEmpty) 'x-api-key': AppConfig.waasApiKey,
      },
      body: jsonEncode({'email': email, 'password': password}),
    )
        .timeout(_timeout);

    if (response.statusCode == 401) {
      WaasService.notifyUnauthorized();
      throw Exception('unauthorized');
    }
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      _accessToken = data['accessToken'] as String?;
      _custodialAddress = data['walletAddress'] as String?;
      return data;
    }
    if (response.statusCode == 409) {
      throw Exception('email_exists');
    }
    throw Exception('Signup failed: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}${AppConfig.waasAuthEndpoint}/signin');
    final response = await _httpClient
        .post(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (AppConfig.waasApiKey.isNotEmpty) 'x-api-key': AppConfig.waasApiKey,
      },
      body: jsonEncode({'email': email, 'password': password}),
    )
        .timeout(_timeout);

    if (response.statusCode == 401) {
      WaasService.notifyUnauthorized();
      throw Exception('unauthorized');
    }
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      _accessToken = data['accessToken'] as String?;
      _custodialAddress = data['walletAddress'] as String?;
      return data;
    }
    throw Exception('Signin failed: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> getProfile() async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}${AppConfig.waasAuthEndpoint}/me');
    final response = await _httpClient
        .get(
          url,
          headers: _authHeaders(),
        )
        .timeout(_timeout);
    if (response.statusCode == 401) {
      throw Exception('unauthorized');
    }
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      _custodialAddress = data['walletAddress'] as String?;
      return data;
    }
    throw Exception('Profile fetch failed: ${response.statusCode}');
  }

  Future<String> sendUSDC({
    required String to,
    required String amountWei,
  }) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}${AppConfig.waasWalletEndpoint}/send');
    final response = await _httpClient
        .post(
          url,
          headers: _authHeaders(),
          body: jsonEncode({
        'to': to,
        'amount': amountWei,
        'token': 'USDC',
        'network': AppConfig.networkChainId,
          }),
        )
        .timeout(_timeout);
    if (response.statusCode == 401) {
      WaasService.notifyUnauthorized();
      throw Exception('unauthorized');
    }
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['txHash'] ?? data['transactionHash'] ?? '') as String;
    }
    throw Exception('WaaS send failed: ${response.statusCode} ${response.body}');
  }

  // Sponsorship removed
  Future<Map<String, dynamic>> sponsorGasIfNeeded() async {
    throw Exception('sponsorship_removed');
  }

  Future<String> sendUSDCSponsored({
    required String to,
    required String amountWei,
  }) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}${AppConfig.waasWalletEndpoint}/send-sponsored');
    final response = await _httpClient
        .post(
          url,
          headers: _authHeaders(),
          body: jsonEncode({ 'to': to, 'amount': amountWei }),
        )
        .timeout(_timeout);
    if (response.statusCode == 401) {
      WaasService.notifyUnauthorized();
      throw Exception('unauthorized');
    }
    throw Exception('sponsorship_removed');
  }

  Future<String> sendUSDC_AA({
    required String to,
    required String amountWei,
  }) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}${AppConfig.waasWalletEndpoint}/send-aa');
    final response = await _httpClient
        .post(
          url,
          headers: _authHeaders(),
          body: jsonEncode({ 'to': to, 'amount': amountWei }),
        )
        .timeout(_timeout);
    if (response.statusCode == 401) {
      WaasService.notifyUnauthorized();
      throw Exception('unauthorized');
    }
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['txHash'] ?? '') as String;
    }
    throw Exception('WaaS AA send failed: ${response.statusCode} ${response.body}');
  }

  Future<Map<String, dynamic>> getBalances() async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}${AppConfig.waasWalletEndpoint}/balance');
    final response = await _httpClient
        .get(
          url,
          headers: _authHeaders(),
        )
        .timeout(_timeout);
    if (response.statusCode == 401) {
      WaasService.notifyUnauthorized();
      throw Exception('unauthorized');
    }
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('WaaS balance failed: ${response.statusCode}');
  }

  Future<List<Map<String, dynamic>>> getTransactions() async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}${AppConfig.waasWalletEndpoint}/transactions');
    final response = await _httpClient
        .get(
          url,
          headers: _authHeaders(),
        )
        .timeout(_timeout);
    if (response.statusCode == 401) {
      throw Exception('unauthorized');
    }
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final List list = data['transactions'] as List? ?? [];
      return list.cast<Map<String, dynamic>>();
    }
    throw Exception('WaaS transactions failed: ${response.statusCode}');
  }

  Map<String, String> _authHeaders() {
    return {
      'Content-Type': 'application/json',
      if (AppConfig.waasApiKey.isNotEmpty) 'x-api-key': AppConfig.waasApiKey,
      if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
    };
  }

  void dispose() {
    _httpClient.close();
  }
}


