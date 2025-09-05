import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/blockchain_service.dart';
import '../config/app_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/waas_service.dart';

class WalletProvider extends ChangeNotifier {
  final BlockchainService _blockchainService = BlockchainService();
  
  // Wallet state
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Wallet data
  String? _walletAddress;
  BigInt _usdcBalance = BigInt.zero;
  BigInt _ethBalance = BigInt.zero;
  
  // Fiat conversion
  String _selectedFiatCurrency = 'USD';
  double _usdcBalanceInFiat = 0.0;
  double _ethBalanceInFiat = 0.0;
  
  // Gas sponsorship removed; always use AA via WaaS when enabled
  bool _useSponsoredGas = false;

  // WaaS
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final WaasService _waasService = WaasService();
  
  // Simple transaction info structure
  List<Map<String, dynamic>> _transactions = [];
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get walletAddress => _walletAddress;
  BigInt get usdcBalance => _usdcBalance;
  BigInt get ethBalance => _ethBalance;
  List<Map<String, dynamic>> get transactions => _transactions;
  
  /// Get only recent transactions (first 4)
  List<Map<String, dynamic>> get recentTransactions {
    if (_transactions.length <= 4) {
      return _transactions;
    }
    return _transactions.take(4).toList();
  }
  
  // Fiat conversion getters
  String get selectedFiatCurrency => _selectedFiatCurrency;
  double get usdcBalanceInFiat => _usdcBalanceInFiat;
  double get ethBalanceInFiat => _ethBalanceInFiat;
  
  // Gas sponsorship getters
  bool get useSponsoredGas => _useSponsoredGas;
  bool get isGasSponsorshipAvailable => _blockchainService.isGasSponsorshipAvailable();
  
  // Network info
  String get networkName => 'Base Sepolia Testnet';
  String get networkChainId => '84532';
  String get usdcContractAddress => '0x036CbD53842c5426634e7929541eC2318f3dCF7e';

  /// Initialize wallet
  Future<void> initializeWallet({String? privateKey}) async {
    try {
      // Don't call _setLoading here to avoid notifyListeners during build
      _isLoading = true;
      _errorMessage = null;
      
      await _blockchainService.initializeWallet(privateKey: privateKey);
      _walletAddress = _blockchainService.walletAddress;
      
      // Load initial data
      await _loadWalletData();
      
      _isInitialized = true;
      _isLoading = false;
      // Don't call notifyListeners here - let the calling widget handle state updates
      
      // Start periodic updates
      _startPeriodicUpdates();
      
    } catch (e) {
      _errorMessage = 'Failed to initialize wallet: $e';
      _isLoading = false;
    }
  }

  /// Initialize wallet from an external custodial address (WaaS)
  Future<void> initializeWithExternalAddress(String address) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      await _blockchainService.initializeReadOnlyWallet(address);
      _walletAddress = address;
      await _loadWalletData();
      _isInitialized = true;
    } catch (e) {
      _errorMessage = 'Failed to initialize external wallet: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load wallet data
  Future<void> _loadWalletData() async {
    try {
      // Load balances
      await _loadBalances();
      
      // Load transaction history
      await _loadTransactionHistory();
      
    } catch (e) {
      print('Error loading wallet data: $e');
    }
  }

  /// Load balances
  Future<void> _loadBalances() async {
    try {
      if (AppConfig.enableWaaS) {
        final token = await _secureStorage.read(key: 'waas_access_token');
        if (token != null && token.isNotEmpty) {
          _waasService.setAccessToken(token);
          final resp = await _waasService.getBalances();
          _walletAddress = (resp['address'] as String?) ?? _walletAddress;
          _ethBalance = BigInt.parse((resp['ethWei'] ?? '0').toString());
          _usdcBalance = BigInt.parse((resp['usdcWei'] ?? '0').toString());
        }
      } else {
        _usdcBalance = await _blockchainService.getUSDCBalance();
        _ethBalance = await _blockchainService.getETHBalance();
      }
      _updateFiatBalances();
      notifyListeners();
    } catch (e) {
      print('Error loading balances: $e');
    }
  }

  /// Load transaction history
  Future<void> _loadTransactionHistory() async {
    try {
      if (AppConfig.enableWaaS) {
        final token = await _secureStorage.read(key: 'waas_access_token');
        if (token != null && token.isNotEmpty) {
          _waasService.setAccessToken(token);
          _transactions = await _waasService.getTransactions();
        } else {
          _transactions = [];
        }
      } else {
        final transactions = await _blockchainService.getTransactionHistoryWithFallback();
        _transactions = transactions;
      }
      notifyListeners();
    } catch (e) {
      print('Error loading transaction history: $e');
    }
  }

  /// Send USDC to another address
  Future<String> sendUSDC(String toAddress, BigInt amount) async {
    try {
      _setLoading(true);
      _clearError();
      
      String txHash;
      if (AppConfig.enableWaaS) {
        final token = await _secureStorage.read(key: 'waas_access_token');
        if (token == null || token.isEmpty) {
          throw Exception('Not signed in');
        }
        _waasService.setAccessToken(token);
        // Always use AA path in WaaS mode
        txHash = await _waasService.sendUSDC_AA(to: toAddress, amountWei: amount.toString());
        // After server returns, refresh history/balances instead of optimistic confirm
        await _loadTransactionHistory();
        await _loadBalances();
      } else {
        txHash = await _blockchainService.sendUSDC(toAddress, amount, useSponsoredGas: _useSponsoredGas);
      }
      
      print('Transaction sent with hash: $txHash');
      
      // Wait for confirmation only for self-managed wallet mode
      if (!AppConfig.enableWaaS) {
        final isConfirmed = await _blockchainService.waitForTransactionConfirmation(txHash);
        print('Transaction confirmation result: $isConfirmed');
        _blockchainService.updateLocalTransactionStatus(
          txHash, 
          isConfirmed ? 'confirmed' : 'failed'
        );
      }
      
      if (!AppConfig.enableWaaS) {
        // Refresh only for self-custody mode; WaaS branch already refreshed
        await _loadTransactionHistory();
        await _loadBalances();
      }
      
      return txHash;
    } catch (e) {
      _setError('Failed to send USDC: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Toggle gas sponsorship (removed)
  void toggleGasSponsorship() {}

  /// Set fiat currency
  void setFiatCurrency(String currency) {
    if (BlockchainService.getAvailableFiatCurrencies().contains(currency)) {
      _selectedFiatCurrency = currency;
      _updateFiatBalances();
      notifyListeners();
    }
  }

  /// Update fiat balances
  void _updateFiatBalances() {
    _usdcBalanceInFiat = BlockchainService.convertUSDCToFiat(_usdcBalance, _selectedFiatCurrency);
    _ethBalanceInFiat = BlockchainService.convertUSDCToFiat(
      BigInt.from((_ethBalance / BigInt.from(1000000000000000000)).toDouble() * 1000000), 
      _selectedFiatCurrency
    );
  }

  /// Get estimated gas cost in fiat
  Future<double> getEstimatedGasCostInFiat() async {
    try {
      return await _blockchainService.getEstimatedGasCostInFiat(_selectedFiatCurrency);
    } catch (e) {
      print('Error getting estimated gas cost: $e');
      return 0.0;
    }
  }

  /// Refresh wallet data
  Future<void> refreshWallet() async {
    try {
      _setLoading(true);
      await _loadWalletData();
      _setLoading(false);
    } catch (e) {
      _setError('Failed to refresh wallet: $e');
      _setLoading(false);
    }
  }

  /// Start periodic updates
  void _startPeriodicUpdates() {
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isInitialized && !_isLoading) {
        _loadBalances();
      }
    });
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error message
  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// Clear error message
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Get local transactions only
  List<Map<String, dynamic>> getLocalTransactions() {
    return _blockchainService.getLocalTransactions();
  }

  /// Add a transaction by hash
  Future<void> addTransactionByHash(String txHash) async {
    await _blockchainService.addTransactionByHash(txHash);
    _loadTransactionHistory();
  }

  /// Add a sample USDC transaction
  void addSampleUSDCTransaction() {
    _blockchainService.addSampleUSDCTransaction();
    _loadTransactionHistory();
  }

  /// Add a test received transaction
  void addTestReceivedTransaction() {
    _blockchainService.addTestReceivedTransaction();
    _loadTransactionHistory();
  }

  /// Add a local transaction
  void addLocalTransaction(BigInt amount, String fromAddress) {
    _blockchainService.addLocalTransaction(
      hash: 'local_${DateTime.now().millisecondsSinceEpoch}',
      type: 'receive',
      amount: amount,
      to: walletAddress ?? '',
      from: fromAddress,
      status: 'confirmed',
    );
    _loadTransactionHistory();
  }

  /// Monitor for all transactions (both send and receive)
  Future<void> monitorAllTransactions() async {
    await _blockchainService.monitorAllTransactions();
    _loadTransactionHistory();
  }

  /// Scan for transactions using direct RPC
  Future<List<Map<String, dynamic>>> scanForTransactionsDirectRPC() async {
    return await _blockchainService.scanForTransactionsDirectRPC();
  }

  /// Scan for received transactions
  Future<List<Map<String, dynamic>>> scanForReceivedTransactions() async {
    return await _blockchainService.scanForReceivedTransactions();
  }

  /// Manually verify transaction status from blockchain
  Future<String> verifyTransactionStatus(String txHash) async {
    return await _blockchainService.verifyTransactionStatus(txHash);
  }

  /// Check transaction status from blockchain (for debugging)
  Future<Map<String, dynamic>?> checkTransactionStatus(String txHash) async {
    return await _blockchainService.checkTransactionStatus(txHash);
  }

  /// Clear test transactions (for testing)
  void clearTestTransactions() {
    _blockchainService.clearTestTransactions();
    _loadTransactionHistory();
  }

  /// Clear local transactions (for testing)
  void clearLocalTransactions() {
    _blockchainService.clearLocalTransactions();
    _loadTransactionHistory();
  }

  /// Get formatted USDC balance
  String get formattedUSDCBalance {
    if (_usdcBalance == BigInt.zero) return '0.00';
    return (_usdcBalance / BigInt.from(1000000)).toStringAsFixed(2);
  }

  /// Get formatted ETH balance
  String get formattedETHBalance {
    if (_ethBalance == BigInt.zero) return '0.00';
    return (_ethBalance / BigInt.from(1000000000000000000)).toStringAsFixed(6);
  }

  /// Get wallet address in short format
  String get shortWalletAddress {
    if (_walletAddress == null) return '';
    final address = _walletAddress!;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  /// Check if wallet has sufficient balance
  bool hasSufficientBalance(double amount) {
    final amountInUnits = BigInt.from((amount * 1000000).round());
    return _usdcBalance >= amountInUnits;
  }

  /// Get estimated gas cost
  Future<String> getEstimatedGasCost() async {
    try {
      final gasPrice = await _blockchainService.getGasPrice();
      final estimatedGas = BigInt.from(100000); // Standard USDC transfer gas
      final totalCost = gasPrice * estimatedGas;
      
      // Convert to ETH
      final ethCost = totalCost / BigInt.from(1000000000000000000);
      return ethCost.toStringAsFixed(6);
    } catch (e) {
      return '0.0001'; // Default estimate
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    _blockchainService.dispose();
    super.dispose();
  }
}
