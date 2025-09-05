import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';

/// Service for handling gas sponsorship via relayers
class RelayerService {
  // Base Gas Station (Base's official gas sponsorship)
  static const String _baseGasStationUrl = 'https://gasstation.base.org';
  
  // Alternative relayers
  static const String _biconomyUrl = 'https://api.biconomy.io';
  static const String _gelatoUrl = 'https://relay.gelato.digital';
  
  final http.Client _httpClient = http.Client();
  
  /// Check if gas sponsorship is available
  Future<bool> isGasSponsorshipAvailable() async {
    try {
      // Check Base Gas Station status
      final response = await _httpClient.get(
        Uri.parse('$_baseGasStationUrl/status'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['sponsorship_enabled'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error checking gas sponsorship availability: $e');
      return false;
    }
  }
  
  /// Get sponsored transaction data
  Future<Map<String, dynamic>> getSponsoredTransaction({
    required String fromAddress,
    required String toAddress,
    required BigInt amount,
    required String contractAddress,
    required String abi,
  }) async {
    try {
      // Create transaction data for USDC transfer
      final functionData = _createUSDCTransferData(toAddress, amount);
      
      // Request sponsorship from Base Gas Station
      final response = await _httpClient.post(
        Uri.parse('$_baseGasStationUrl/sponsor'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'from': fromAddress,
          'to': contractAddress,
          'data': functionData,
          'value': '0x0', // USDC transfer doesn't send ETH
          'chainId': 84532, // Base Sepolia
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'sponsoredTx': data['sponsored_transaction'],
          'gasLimit': data['gas_limit'],
          'gasPrice': data['gas_price'],
        };
      } else {
        throw Exception('Failed to get sponsored transaction: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting sponsored transaction: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Submit sponsored transaction
  Future<String> submitSponsoredTransaction(Map<String, dynamic> sponsoredTx) async {
    try {
      // Submit the sponsored transaction to the network
      final response = await _httpClient.post(
        Uri.parse('$_baseGasStationUrl/submit'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(sponsoredTx),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['transaction_hash'] ?? 'Unknown hash';
      } else {
        throw Exception('Failed to submit sponsored transaction: ${response.statusCode}');
      }
    } catch (e) {
      print('Error submitting sponsored transaction: $e');
      rethrow;
    }
  }
  
  /// Create USDC transfer function data
  String _createUSDCTransferData(String toAddress, BigInt amount) {
    // USDC transfer function signature: transfer(address,uint256)
    const functionSignature = 'transfer(address,uint256)';
    final functionSelector = _getFunctionSelector(functionSignature);
    
    // Encode parameters
    final encodedAddress = _encodeAddress(toAddress);
    final encodedAmount = _encodeUint256(amount);
    
    return '0x$functionSelector$encodedAddress$encodedAmount';
  }
  
  /// Get function selector (first 4 bytes of function signature hash)
  String _getFunctionSelector(String functionSignature) {
    // In a real implementation, you'd use keccak256
    // For demo purposes, return a mock selector
    return 'a9059cbb'; // transfer(address,uint256) selector
  }
  
  /// Encode Ethereum address parameter
  String _encodeAddress(String address) {
    // Remove 0x prefix and pad to 64 characters
    final cleanAddress = address.startsWith('0x') ? address.substring(2) : address;
    return cleanAddress.padLeft(64, '0');
  }
  
  /// Encode uint256 parameter
  String _encodeUint256(BigInt value) {
    // Convert to hex and pad to 64 characters
    final hexValue = value.toRadixString(16);
    return hexValue.padLeft(64, '0');
  }
  
  /// Get gas sponsorship status
  Future<Map<String, dynamic>> getSponsorshipStatus() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$_baseGasStationUrl/status'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'error': 'Failed to get status'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }
  
  /// Dispose resources
  void dispose() {
    _httpClient.close();
  }
}
