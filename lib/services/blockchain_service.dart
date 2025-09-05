import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:bip39/bip39.dart';
import 'relayer_service.dart';

class BlockchainService {
  // Base Sepolia Testnet configuration
  static const String _baseTestnetRpc = 'https://sepolia.base.org';
  static const int _baseTestnetChainId = 84532;
  static const String _usdcContractAddress = '0x036CbD53842c5426634e7929541eC2318f3dCF7e'; // Base Sepolia USDC
  
  // Gas sponsorship configuration
  static const bool _enableSponsoredGas = true;
  
  late Web3Client _client;
  late EthPrivateKey _privateKey;
  String? _walletAddress;
  
  // USDC contract instance
  DeployedContract? _usdcContract;
  ContractFunction? _balanceOfFunction;
  ContractFunction? _transferFunction;
  
  // Relayer service for gas sponsorship
  late RelayerService _relayerService;
  
  // Simple in-memory storage for demo purposes
  static String? _storedPrivateKey;
  
  // Local transaction storage
  static final List<Map<String, dynamic>> _localTransactions = [];
  
  // Fiat conversion rates (mock data - replace with real API)
  static const Map<String, double> _fiatRates = {
    'USD': 1.0,
    'EUR': 0.85,
    'GBP': 0.73,
    'JPY': 110.0,
  };
  
  BlockchainService() {
    _client = Web3Client(_baseTestnetRpc, http.Client());
    _relayerService = RelayerService();
    // Don't initialize USDC contract here - wait for wallet initialization
  }

  /// Initialize wallet in read-only mode using an external address (e.g., WaaS custodial address)
  Future<void> initializeReadOnlyWallet(String externalAddress) async {
    _walletAddress = externalAddress;
    _initializeUSDCContract();
  }

  void _initializeUSDCContract() {
    // USDC ERC20 ABI for balanceOf and transfer functions
    _usdcContract = DeployedContract(
      ContractAbi.fromJson(
        jsonEncode([
          {
            "constant": true,
            "inputs": [{"name": "_owner", "type": "address"}],
            "name": "balanceOf",
            "outputs": [{"name": "balance", "type": "uint256"}],
            "type": "function"
          },
          {
            "constant": false,
            "inputs": [
              {"name": "_to", "type": "address"},
              {"name": "_value", "type": "uint256"}
            ],
            "name": "transfer",
            "outputs": [{"name": "", "type": "bool"}],
            "type": "function"
          }
        ]),
        'USDC',
      ),
      EthereumAddress.fromHex(_usdcContractAddress),
    );
    
    _balanceOfFunction = _usdcContract?.function('balanceOf');
    _transferFunction = _usdcContract?.function('transfer');
  }

  /// Initialize wallet with private key or generate new one
  Future<void> initializeWallet({String? privateKey}) async {
    if (privateKey != null) {
      _privateKey = EthPrivateKey.fromHex(privateKey);
      _walletAddress = _privateKey.address.hex;
    } else {
      // Generate new wallet using BIP39 mnemonic
      final mnemonic = generateMnemonic();
      final seed = mnemonicToSeed(mnemonic);
      final privateKeyBytes = seed.sublist(0, 32);
      _privateKey = EthPrivateKey(privateKeyBytes);
      _walletAddress = _privateKey.address.hex;
      
      // Save private key securely
      _savePrivateKey(privateKeyBytes);
      
      print('Generated new wallet with mnemonic: $mnemonic');
      print('Wallet address: $_walletAddress');
    }
    _initializeUSDCContract(); // Initialize USDC contract after wallet is set
  }

  /// Get wallet address
  String get walletAddress {
    if (_walletAddress == null) {
      throw Exception('Wallet not initialized. Call initializeWallet() first.');
    }
    return _walletAddress!;
  }

  /// Get USDC balance from smart contract
  Future<BigInt> getUSDCBalance() async {
    try {
      // Check if contract is initialized
      if (_usdcContract == null || _balanceOfFunction == null) {
        print('USDC contract not initialized yet');
        return BigInt.zero; // Return zero if contract not ready
      }
      
      final result = await _client.call(
        contract: _usdcContract!,
        function: _balanceOfFunction!,
        params: [EthereumAddress.fromHex(walletAddress)],
      );
      
      if (result.isNotEmpty) {
        return result.first as BigInt;
      }
      return BigInt.zero;
    } catch (e) {
      print('Error getting USDC balance: $e');
      return BigInt.zero; // Return zero on error
    }
  }

  /// Get ETH balance
  Future<BigInt> getETHBalance() async {
    try {
      // Check if wallet is initialized
      if (_walletAddress == null) {
        print('Wallet not initialized yet');
        return BigInt.zero; // Return zero if wallet not initialized
      }
      
      final balance = await _client.getBalance(EthereumAddress.fromHex(walletAddress));
      return balance.getInWei;
    } catch (e) {
      print('Error getting ETH balance: $e');
      return BigInt.zero; // Return zero on error
    }
  }

  /// Send USDC to another address with optional gas sponsorship
  Future<String> sendUSDC(String toAddress, BigInt amount, {bool useSponsoredGas = false}) async {
    try {
      // Check if wallet is initialized
      if (_walletAddress == null) {
        throw Exception('Wallet not initialized. Call initializeWallet() first.');
      }
      
      // Validate address format
      if (!toAddress.startsWith('0x') || toAddress.length != 42) {
        throw Exception('Invalid recipient address format');
      }

      // Check if we have sufficient USDC balance
      final currentBalance = await getUSDCBalance();
      if (currentBalance < amount) {
        throw Exception('Insufficient USDC balance');
      }

      if (useSponsoredGas && _enableSponsoredGas) {
        // Use gas sponsorship via relayer
        final txHash = await _sendUSDCWithSponsoredGas(toAddress, amount);
        
        // Add to local transaction history
        addLocalTransaction(
          hash: txHash,
          type: 'send',
          amount: amount,
          to: toAddress,
          from: walletAddress,
          status: 'pending',
        );
        
        return txHash;
      } else {
        // Use regular gas payment
        final txHash = await _sendUSDCWithRegularGas(toAddress, amount);
        
        // Add to local transaction history
        addLocalTransaction(
          hash: txHash,
          type: 'send',
          amount: amount,
          to: toAddress,
          from: walletAddress,
          status: 'pending',
        );
        
        return txHash;
      }
    } catch (e) {
      print('Error sending USDC: $e');
      rethrow;
    }
  }

  /// Send USDC using regular gas payment
  Future<String> _sendUSDCWithRegularGas(String toAddress, BigInt amount) async {
    try {
      // Check if we have sufficient ETH for gas
      final ethBalance = await getETHBalance();
      final gasPrice = await getGasPrice();
      final estimatedGas = BigInt.from(100000); // Standard USDC transfer gas
      final gasCost = gasPrice * estimatedGas;
      
      if (ethBalance < gasCost) {
        throw Exception('Insufficient ETH for gas fees');
      }

      // Check if USDC contract is initialized
      if (_usdcContract == null || _transferFunction == null) {
        throw Exception('USDC contract not initialized');
      }

      // Create the transaction
      final transaction = await _client.sendTransaction(
        _privateKey,
        Transaction(
          to: EthereumAddress.fromHex(_usdcContractAddress),
          data: _transferFunction!.encodeCall([
            EthereumAddress.fromHex(toAddress),
            amount,
          ]),
          gasPrice: EtherAmount.inWei(gasPrice),
          maxGas: estimatedGas.toInt(),
        ),
        chainId: _baseTestnetChainId,
      );

      print('Transaction sent: ${transaction}');
      return transaction;
    } catch (e) {
      print('Error sending USDC with regular gas: $e');
      rethrow;
    }
  }

  /// Send USDC using gas sponsorship via relayer
  Future<String> _sendUSDCWithSponsoredGas(String toAddress, BigInt amount) async {
    try {
      // Check if gas sponsorship is available
      final isAvailable = await _relayerService.isGasSponsorshipAvailable();
      if (!isAvailable) {
        print('Gas sponsorship not available, falling back to regular gas');
        return await _sendUSDCWithRegularGas(toAddress, amount);
      }
      
      // Get sponsored transaction data
      final sponsoredData = await _relayerService.getSponsoredTransaction(
        fromAddress: walletAddress,
        toAddress: toAddress,
        amount: amount,
        contractAddress: _usdcContractAddress,
        abi: 'USDC_ABI', // In real implementation, pass actual ABI
      );
      
      if (sponsoredData['success'] == true) {
        // Submit the sponsored transaction
        final txHash = await _relayerService.submitSponsoredTransaction(
          sponsoredData['sponsoredTx'],
        );
        
        print('Sponsored transaction submitted: $txHash');
        return txHash;
      } else {
        print('Failed to get sponsored transaction: ${sponsoredData['error']}');
        // Fallback to regular gas
        return await _sendUSDCWithRegularGas(toAddress, amount);
      }
    } catch (e) {
      print('Error with sponsored gas transaction: $e');
      // Fallback to regular gas if sponsorship fails
      return await _sendUSDCWithRegularGas(toAddress, amount);
    }
  }

  /// Add a sample USDC transaction for testing
  void addSampleUSDCTransaction() {
    final sampleTx = {
      'hash': 'sample_usdc_${DateTime.now().millisecondsSinceEpoch}',
      'type': 'receive',
      'amount': '5000000', // 5 USDC (6 decimals)
      'to': walletAddress,
      'from': '0x742d35Cc6634C0532925a3b8D4C9db96C4b4d8b6',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'status': 'confirmed',
      'gasUsed': '45059',
      'gasPrice': '2000000000',
      'token': 'USDC',
    };
    
    _localTransactions.add(sampleTx);
    print('Added sample USDC transaction: $sampleTx');
  }

  /// Add a test received transaction for demonstration
  void addTestReceivedTransaction() {
    final testTx = {
      'hash': 'test_received_${DateTime.now().millisecondsSinceEpoch}',
      'type': 'receive',
      'amount': '1000000', // 1 USDC (6 decimals)
      'to': walletAddress,
      'from': '0x742d35Cc6634C0532925a3b8D4C9db96C4b4d8b6',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'status': 'confirmed',
      'gasUsed': '45059',
      'gasPrice': '2000000000',
    };
    
    _localTransactions.add(testTx);
    print('Added test received transaction: $testTx');
  }

  /// Update local transaction status
  void updateLocalTransactionStatus(String hash, String status) {
    for (int i = 0; i < _localTransactions.length; i++) {
      if (_localTransactions[i]['hash'] == hash) {
        _localTransactions[i]['status'] = status;
        break;
      }
    }
  }

  /// Add a local transaction to history
  void addLocalTransaction({
    required String hash,
    required String type,
    required BigInt amount,
    required String to,
    required String from,
    required String status,
  }) {
    _localTransactions.add({
      'hash': hash,
      'type': type,
      'amount': amount.toString(),
      'to': to,
      'from': from,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'status': status,
      'gasUsed': '0',
      'gasPrice': '0',
      'isLocal': true,
    });
  }

  /// Clear all local transactions (for testing purposes)
  void clearLocalTransactions() {
    _localTransactions.clear();
  }

  /// Clear test transactions from local storage
  void clearTestTransactions() {
    _localTransactions.removeWhere((tx) => tx['hash'].toString().startsWith('test_'));
    print('Cleared test transactions. Remaining local transactions: ${_localTransactions.length}');
  }

  /// Get local transactions only
  List<Map<String, dynamic>> getLocalTransactions() {
    return List.from(_localTransactions);
  }

  /// Filter out test transactions from the list
  List<Map<String, dynamic>> filterTestTransactions(List<Map<String, dynamic>> transactions) {
    return transactions.where((tx) => !tx['hash'].toString().startsWith('test_')).toList();
  }

  /// Get transaction history from blockchain
  Future<List<Map<String, dynamic>>> getTransactionHistory() async {
    try {
      // Check if wallet is initialized
      if (_walletAddress == null) {
        print('Wallet not initialized yet');
        return []; // Return empty list if wallet not initialized
      }
      
      final transactions = <Map<String, dynamic>>[];
      
      // Try to get real transaction history from BaseScan API (without API key for now)
      try {
        final response = await http.get(
          Uri.parse('https://api-sepolia.basescan.org/api?module=account&action=txlist&address=${walletAddress}&startblock=0&endblock=99999999&sort=desc'),
        ).timeout(const Duration(seconds: 10));
        
        print('BaseScan API response status: ${response.statusCode}');
        print('BaseScan API response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print('BaseScan API response: ${data['status']}');
          print('BaseScan API message: ${data['message'] ?? 'No message'}');
          
          if (data['status'] == '1' && data['result'] != null) {
            print('Found ${data['result'].length} transactions from BaseScan');
            
            for (final tx in data['result']) {
              print('Processing transaction: ${tx['hash']}');
              print('  To: ${tx['to']}');
              print('  From: ${tx['from']}');
              print('  Input: ${tx['input']?.toString().substring(0, (tx['input']?.toString().length ?? 0) > 100 ? 100 : (tx['input']?.toString().length ?? 0))}...');
              
              // Check if this is a USDC transaction (either to or from USDC contract)
              final isToUSDC = tx['to']?.toString().toLowerCase() == _usdcContractAddress.toLowerCase();
              final isFromUSDC = tx['from']?.toString().toLowerCase() == _usdcContractAddress.toLowerCase();
              
              if (isToUSDC || isFromUSDC) {
                print('  This is a USDC transaction!');
                
                // Determine transaction type and addresses
                String type;
                String fromAddress;
                String toAddress;
                
                if (tx['from'].toString().toLowerCase() == walletAddress.toLowerCase()) {
                  // We sent USDC
                  type = 'send';
                  fromAddress = walletAddress;
                  toAddress = tx['to']?.toString() ?? '';
                  print('  Type: SEND (we sent USDC)');
                } else if (tx['to']?.toString().toLowerCase() == walletAddress.toLowerCase()) {
                  // We received USDC
                  type = 'receive';
                  fromAddress = tx['from']?.toString() ?? '';
                  toAddress = walletAddress;
                  print('  Type: RECEIVE (we received USDC)');
                } else if (isToUSDC) {
                  // Someone sent USDC to the contract (might be to us)
                  // Check if the input data contains our address
                  final inputData = tx['input']?.toString() ?? '';
                  if (inputData.length > 74) {
                    // Parse the recipient address from input data
                    final recipientHex = inputData.substring(34, 74); // Skip function selector and get address
                    final recipientAddress = '0x$recipientHex';
                    print('  Recipient from input data: $recipientAddress');
                    
                    if (recipientAddress.toLowerCase() == walletAddress.toLowerCase()) {
                      type = 'receive';
                      fromAddress = tx['from']?.toString() ?? '';
                      toAddress = walletAddress;
                      print('  Type: RECEIVE (USDC sent to our address)');
                    } else {
                      print('  Not to our address, skipping');
                      continue;
                    }
                  } else {
                    print('  Input data too short, skipping');
                    continue;
                  }
                } else {
                  print('  Not a transaction involving our wallet, skipping');
                  continue;
                }
                
                final amount = _parseUSDCAmount(tx['input']?.toString() ?? '');
                print('  Amount: $amount');
                
                if (amount > BigInt.zero) {
                  final isError = tx['isError']?.toString() ?? '0';
                  final status = isError == '0' ? 'confirmed' : 'failed';
                  print('  Final status: $status');
                  print('  Adding to transactions list');
                  
                  transactions.add({
                    'hash': tx['hash'],
                    'type': type,
                    'amount': amount.toString(),
                    'to': toAddress,
                    'from': fromAddress,
                    'timestamp': int.parse(tx['timeStamp'].toString()) * 1000, // Convert to milliseconds
                    'status': status,
                    'gasUsed': tx['gasUsed']?.toString() ?? '0',
                    'gasPrice': tx['gasPrice']?.toString() ?? '0',
                  });
                } else {
                  print('  Amount is zero, skipping');
                }
              } else {
                print('  Not a USDC transaction (to: ${tx['to']}, expected: $_usdcContractAddress)');
              }
            }
          } else {
            print('BaseScan API error: ${data['message'] ?? 'Unknown error'}');
            print('Full response: $data');
          }
        } else {
          print('BaseScan API HTTP error: ${response.statusCode}');
          print('Response body: ${response.body}');
        }
      } catch (e) {
        print('Error fetching from BaseScan: $e');
      }
      
      // If no transactions found from API, try to get from blockchain directly
      if (transactions.isEmpty) {
        try {
          // For now, skip direct blockchain scanning as it's complex and error-prone
          // Focus on local transactions and API results
          print('Skipping direct blockchain scan - using local transactions and API results');
        } catch (e) {
          print('Error with blockchain scanning: $e');
        }
      }
      
      // Combine local and blockchain transactions
      print('Local transactions count: ${_localTransactions.length}');
      transactions.addAll(_localTransactions);

      // Filter out test transactions
      final filteredTransactions = filterTestTransactions(transactions);
      print('Transactions after filtering test transactions: ${filteredTransactions.length}');

      // Sort transactions by timestamp (newest first)
      filteredTransactions.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
      
      print('Total transactions found: ${filteredTransactions.length}');
      return filteredTransactions;
    } catch (e) {
      print('Error getting transaction history: $e');
      return [];
    }
  }

  /// Add a transaction by hash (for testing)
  Future<void> addTransactionByHash(String txHash) async {
    try {
      print('=== ADDING TRANSACTION BY HASH: $txHash ===');
      
      // Get transaction receipt
      final receipt = await _client.getTransactionReceipt(txHash);
      if (receipt == null) {
        print('Transaction receipt not found');
        return;
      }
      
      print('Transaction receipt found:');
      print('  Status: ${receipt.status}');
      print('  Block: ${receipt.blockNumber}');
      print('  Gas used: ${receipt.gasUsed}');
      
      // Get transaction details
      final tx = await _client.getTransactionByHash(txHash);
      if (tx == null) {
        print('Transaction not found');
        return;
      }
      
      print('Transaction details:');
      print('  From: ${tx.from}');
      print('  To: ${tx.to}');
      print('  Input: ${tx.input != null ? String.fromCharCodes(tx.input!).substring(0, (tx.input!.length) > 100 ? 100 : (tx.input!.length)) : 'null'}...');
      
      // Check if this is a USDC transaction
      if (tx.to?.hex.toLowerCase() == _usdcContractAddress.toLowerCase()) {
        print('This is a USDC transaction');
        
        // Parse the transaction
        String type;
        String fromAddress;
        String toAddress;
        
        if (tx.from.hex.toLowerCase() == walletAddress.toLowerCase()) {
          type = 'send';
          fromAddress = walletAddress;
          toAddress = tx.to?.hex ?? '';
        } else {
          // Check if we're the recipient
          final inputData = tx.input != null ? String.fromCharCodes(tx.input!) : '';
          if (inputData.length > 74 && inputData.startsWith('0xa9059cbb')) {
            final recipientHex = inputData.substring(34, 74);
            final recipientAddress = '0x$recipientHex';
            
            if (recipientAddress.toLowerCase() == walletAddress.toLowerCase()) {
              type = 'receive';
              fromAddress = tx.from.hex;
              toAddress = walletAddress;
            } else {
              print('Not to our address: $recipientAddress');
              return;
            }
          } else {
            print('Not a valid USDC transfer');
            return;
          }
        }
        
        final amount = _parseUSDCAmount(tx.input != null ? String.fromCharCodes(tx.input!) : '');
        if (amount > BigInt.zero) {
          final status = receipt.status == true ? 'confirmed' : 'failed';
          
          final transaction = {
            'hash': txHash,
            'type': type,
            'amount': amount.toString(),
            'to': toAddress,
            'from': fromAddress,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'status': status,
            'gasUsed': receipt.gasUsed.toString(),
            'gasPrice': tx.gasPrice?.toString() ?? '0',
          };
          
          addLocalTransaction(
            hash: txHash,
            type: type,
            amount: amount,
            to: toAddress,
            from: fromAddress,
            status: status,
          );
          
          print('Added USDC transaction: $transaction');
        }
      } else if (tx.to?.hex.toLowerCase() == walletAddress.toLowerCase()) {
        // This is an ETH transaction TO our wallet
        print('This is an ETH transaction TO our wallet');
        
        final ethAmount = tx.value.getInWei;
        if (ethAmount > BigInt.zero) {
          final status = receipt.status == true ? 'confirmed' : 'failed';
          
          final transaction = {
            'hash': txHash,
            'type': 'receive',
            'amount': ethAmount.toString(),
            'to': walletAddress,
            'from': tx.from.hex,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'status': status,
            'gasUsed': receipt.gasUsed.toString(),
            'gasPrice': tx.gasPrice?.toString() ?? '0',
            'token': 'ETH',
          };
          
          addLocalTransaction(
            hash: txHash,
            type: 'receive',
            amount: ethAmount,
            to: walletAddress,
            from: tx.from.hex,
            status: status,
          );
          
          print('Added ETH received transaction: $transaction');
        }
      } else if (tx.from.hex.toLowerCase() == walletAddress.toLowerCase()) {
        // This is an ETH transaction FROM our wallet
        print('This is an ETH transaction FROM our wallet');
        
        final ethAmount = tx.value.getInWei;
        if (ethAmount > BigInt.zero) {
          final status = receipt.status == true ? 'confirmed' : 'failed';
          
          final transaction = {
            'hash': txHash,
          'type': 'send',
            'amount': ethAmount.toString(),
            'to': tx.to?.hex ?? '',
          'from': walletAddress,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'status': status,
            'gasUsed': receipt.gasUsed.toString(),
            'gasPrice': tx.gasPrice?.toString() ?? '0',
            'token': 'ETH',
          };
          
          addLocalTransaction(
            hash: txHash,
            type: 'send',
            amount: ethAmount,
            to: tx.to?.hex ?? '',
            from: walletAddress,
            status: status,
          );
          
          print('Added ETH sent transaction: $transaction');
        }
      } else {
        print('This transaction does not involve our wallet');
        print('  From: ${tx.from.hex}');
        print('  To: ${tx.to?.hex}');
        print('  Our wallet: $walletAddress');
      }
    } catch (e) {
      print('Error adding transaction by hash: $e');
    }
  }

  /// Monitor for all transactions involving our wallet (both send and receive)
  Future<void> monitorAllTransactions() async {
    try {
      print('=== MONITORING ALL TRANSACTIONS ===');
      
      // Get current transaction history from API
      try {
        final response = await http.get(
          Uri.parse('https://api-sepolia.basescan.org/api?module=account&action=txlist&address=${walletAddress}&startblock=0&endblock=99999999&sort=desc'),
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print('BaseScan API response: ${data['status']}');
          
          if (data['status'] == '1' && data['result'] != null) {
            print('Found ${data['result'].length} total transactions from BaseScan');
            
            // Process ALL transactions using the same logic as addTransactionByHash
            for (final txData in data['result']) {
              await _processTransactionFromAPI(txData);
            }
            
            print('Transaction monitoring completed');
          } else {
            print('BaseScan API error: ${data['message']}');
          }
        }
      } catch (e) {
        print('Error in transaction monitoring: $e');
      }
    } catch (e) {
      print('Error monitoring transactions: $e');
    }
  }

  /// Process a single transaction from API data using the same logic as addTransactionByHash
  Future<void> _processTransactionFromAPI(Map<String, dynamic> txData) async {
    try {
      final txHash = txData['hash'];
      print('Processing transaction: $txHash');
      print('  To: ${txData['to']}');
      print('  From: ${txData['from']}');
      print('  Input: ${txData['input']?.toString().substring(0, (txData['input']?.toString().length ?? 0) > 100 ? 100 : (txData['input']?.toString().length ?? 0))}...');
      
      // Check if this transaction involves our wallet
      final fromOurWallet = txData['from'].toString().toLowerCase() == walletAddress.toLowerCase();
      final toOurWallet = txData['to']?.toString().toLowerCase() == walletAddress.toLowerCase();
      final toUSDCContract = txData['to']?.toString().toLowerCase() == _usdcContractAddress.toLowerCase();
      
      if (!fromOurWallet && !toOurWallet && !toUSDCContract) {
        print('  Transaction does not involve our wallet, skipping');
        return;
      }
      
      // Check if we already have this transaction
      final existingTx = _localTransactions.firstWhere(
        (tx) => tx['hash'] == txHash,
        orElse: () => <String, dynamic>{},
      );
      
      if (existingTx.isNotEmpty) {
        print('  Transaction already exists in local storage, skipping');
        return;
      }
      
      // Determine transaction type and details
      String type;
      String fromAddress;
      String toAddress;
      BigInt amount;
      String token = 'ETH';
      
      if (toUSDCContract) {
        // This is a USDC transaction
        print('  This is a USDC transaction');
        token = 'USDC';
        
        if (fromOurWallet) {
          // We sent USDC
          type = 'send';
          fromAddress = walletAddress;
          toAddress = txData['to']?.toString() ?? '';
          print('  Type: SEND USDC');
        } else {
          // Check if we're the recipient
          final inputData = txData['input']?.toString() ?? '';
          if (inputData.length > 74 && inputData.startsWith('0xa9059cbb')) {
            final recipientHex = inputData.substring(34, 74);
            final recipientAddress = '0x$recipientHex';
            
            if (recipientAddress.toLowerCase() == walletAddress.toLowerCase()) {
              type = 'receive';
              fromAddress = txData['from']?.toString() ?? '';
              toAddress = walletAddress;
              print('  Type: RECEIVE USDC');
            } else {
              print('  USDC transfer not to our address, skipping');
              return;
            }
          } else {
            print('  Not a valid USDC transfer, skipping');
            return;
          }
        }
        
        amount = _parseUSDCAmount(txData['input']?.toString() ?? '');
      } else {
        // This is an ETH transaction
        print('  This is an ETH transaction');
        token = 'ETH';
        
        if (fromOurWallet) {
          type = 'send';
          fromAddress = walletAddress;
          toAddress = txData['to']?.toString() ?? '';
          print('  Type: SEND ETH');
        } else if (toOurWallet) {
          type = 'receive';
          fromAddress = txData['from']?.toString() ?? '';
          toAddress = walletAddress;
          print('  Type: RECEIVE ETH');
        } else {
          print('  ETH transaction does not involve our wallet, skipping');
          return;
        }
        
        // Parse ETH amount from value field
        amount = BigInt.parse(txData['value']?.toString() ?? '0');
      }
      
      if (amount > BigInt.zero) {
        final isError = txData['isError']?.toString() ?? '0';
        final status = isError == '0' ? 'confirmed' : 'failed';
        
        final transaction = {
          'hash': txHash,
          'type': type,
          'amount': amount.toString(),
          'to': toAddress,
          'from': fromAddress,
          'timestamp': int.parse(txData['timeStamp'].toString()) * 1000,
          'status': status,
          'gasUsed': txData['gasUsed']?.toString() ?? '0',
          'gasPrice': txData['gasPrice']?.toString() ?? '0',
          'token': token,
        };
        
        _localTransactions.add(transaction);
        print('  ✅ Added $type $token transaction: ${amount.toString()} $token');
      } else {
        print('  Amount is zero, skipping');
      }
    } catch (e) {
      print('Error processing transaction ${txData['hash']}: $e');
    }
  }

  /// Get transaction history with fallback methods
  Future<List<Map<String, dynamic>>> getTransactionHistoryWithFallback() async {
    try {
      print('=== GETTING TRANSACTION HISTORY WITH FALLBACK ===');
      
      // First, monitor for all transactions (this will add any new ones)
      await monitorAllTransactions();
      
      // Return all local transactions (now includes both sent and received)
      final allTxs = getLocalTransactions();
      print('Total transactions found: ${allTxs.length}');
      
      // Sort by timestamp (newest first)
      allTxs.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
      
      return allTxs;
      
    } catch (e) {
      print('Error in fallback method: $e');
      return getLocalTransactions();
    }
  }

  /// Parse BaseScan API transactions
  List<Map<String, dynamic>> _parseBaseScanTransactions(List<dynamic> apiTransactions) {
    final transactions = <Map<String, dynamic>>[];
    
    for (final tx in apiTransactions) {
      print('Processing API transaction: ${tx['hash']}');
      print('  To: ${tx['to']}');
      print('  From: ${tx['from']}');
      print('  Input: ${tx['input']?.substring(0, tx['input']?.length ?? 0 > 100 ? 100 : tx['input']?.length ?? 0)}...');
      
      // Check if this is a USDC transaction (either to or from USDC contract)
      final isToUSDC = tx['to']?.toString().toLowerCase() == _usdcContractAddress.toLowerCase();
      final isFromUSDC = tx['from']?.toString().toLowerCase() == _usdcContractAddress.toLowerCase();
      
      if (isToUSDC || isFromUSDC) {
        print('  This is a USDC transaction!');
        
        // Determine transaction type and addresses
        String type;
        String fromAddress;
        String toAddress;
        
        if (tx['from'].toString().toLowerCase() == walletAddress.toLowerCase()) {
          // We sent USDC
          type = 'send';
          fromAddress = walletAddress;
          toAddress = tx['to']?.toString() ?? '';
          print('  Type: SEND (we sent USDC)');
        } else if (tx['to']?.toString().toLowerCase() == walletAddress.toLowerCase()) {
          // We received USDC
          type = 'receive';
          fromAddress = tx['from']?.toString() ?? '';
          toAddress = walletAddress;
          print('  Type: RECEIVE (we received USDC)');
        } else if (isToUSDC) {
          // Someone sent USDC to the contract (might be to us)
          // Check if the input data contains our address
          final inputData = tx['input']?.toString() ?? '';
          if (inputData.length > 74) {
            // Parse the recipient address from input data
            final recipientHex = inputData.substring(34, 74); // Skip function selector and get address
            final recipientAddress = '0x$recipientHex';
            print('  Recipient from input data: $recipientAddress');
            
            if (recipientAddress.toLowerCase() == walletAddress.toLowerCase()) {
              type = 'receive';
              fromAddress = tx['from']?.toString() ?? '';
              toAddress = walletAddress;
              print('  Type: RECEIVE (USDC sent to our address)');
            } else {
              print('  Not to our address, skipping');
              continue;
            }
          } else {
            print('  Input data too short, skipping');
            continue;
          }
        } else {
          print('  Not a transaction involving our wallet, skipping');
          continue;
        }
        
        final amount = _parseUSDCAmount(tx['input']?.toString() ?? '');
        print('  Amount: $amount');
        
        if (amount > BigInt.zero) {
          final isError = tx['isError']?.toString() ?? '0';
          final status = isError == '0' ? 'confirmed' : 'failed';
          print('  Final status: $status');
          print('  Adding to transactions list');
          
          transactions.add({
            'hash': tx['hash'],
            'type': type,
            'amount': amount.toString(),
            'to': toAddress,
            'from': fromAddress,
            'timestamp': int.parse(tx['timeStamp'].toString()) * 1000, // Convert to milliseconds
            'status': status,
            'gasUsed': tx['gasUsed']?.toString() ?? '0',
            'gasPrice': tx['gasPrice']?.toString() ?? '0',
          });
        } else {
          print('  Amount is zero, skipping');
        }
      } else {
        print('  Not a USDC transaction (to: ${tx['to']}, expected: $_usdcContractAddress)');
      }
    }
    
    return transactions;
  }

  /// Scan for transactions using direct RPC (no API key needed)
  Future<List<Map<String, dynamic>>> scanForTransactionsDirectRPC() async {
    try {
      print('=== SCANNING FOR TRANSACTIONS USING DIRECT RPC ===');
      final foundTransactions = <Map<String, dynamic>>[];
      
      print('Direct RPC scan completed. Found ${foundTransactions.length} transactions');
      print('Note: Direct block scanning is not fully implemented yet');
      print('Use "Add by Hash" with real transaction hashes instead');
      
      return foundTransactions;
    } catch (e) {
      print('Error scanning for transactions: $e');
      return [];
    }
  }

  /// Manually scan for received transactions
  Future<List<Map<String, dynamic>>> scanForReceivedTransactions() async {
    try {
      print('=== SCANNING FOR RECEIVED TRANSACTIONS ===');
      final receivedTransactions = <Map<String, dynamic>>[];
      
      // Try to get transactions from BaseScan API
      try {
        final response = await http.get(
          Uri.parse('https://api-sepolia.basescan.org/api?module=account&action=txlist&address=${walletAddress}&startblock=0&endblock=99999999&sort=desc'),
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print('BaseScan API response: ${data['status']}');
          
          if (data['status'] == '1' && data['result'] != null) {
            print('Found ${data['result'].length} total transactions from BaseScan');
            
            for (final tx in data['result']) {
              print('Scanning transaction: ${tx['hash']}');
              print('  To: ${tx['to']}');
              print('  From: ${tx['from']}');
              print('  Input: ${tx['input']?.toString().substring(0, (tx['input']?.toString().length ?? 0) > 100 ? 100 : (tx['input']?.toString().length ?? 0))}...');
              
              // Check if this transaction involves USDC
              if (tx['to']?.toString().toLowerCase() == _usdcContractAddress.toLowerCase()) {
                print('  USDC contract involved');
                
                // Check if we're the recipient
                final inputData = tx['input']?.toString() ?? '';
                if (inputData.length > 74 && inputData.startsWith('0xa9059cbb')) {
                  // Parse recipient address from input data
                  final recipientHex = inputData.substring(34, 74);
                  final recipientAddress = '0x$recipientHex';
                  print('  Recipient from input: $recipientAddress');
                  print('  Our address: $walletAddress');
                  
                  if (recipientAddress.toLowerCase() == walletAddress.toLowerCase()) {
                    print('  *** RECEIVED TRANSACTION DETECTED! ***');
                    
                    final amount = _parseUSDCAmount(inputData);
                    if (amount > BigInt.zero) {
                      final isError = tx['isError']?.toString() ?? '0';
                      final receivedTx = {
                        'hash': tx['hash'],
          'type': 'receive',
                        'amount': amount.toString(),
          'to': walletAddress,
                        'from': tx['from']?.toString() ?? '',
                        'timestamp': int.parse(tx['timeStamp'].toString()) * 1000,
                        'status': isError == '0' ? 'confirmed' : 'failed',
                        'gasUsed': tx['gasUsed']?.toString() ?? '0',
                        'gasPrice': tx['gasPrice']?.toString() ?? '0',
                      };
                      
                      receivedTransactions.add(receivedTx);
                      print('  Added received transaction: $receivedTx');
                    }
                  } else {
                    print('  Not to our address');
                  }
                }
              }
            }
          }
        }
    } catch (e) {
        print('Error scanning BaseScan: $e');
      }
      
      print('Found ${receivedTransactions.length} received transactions');
      return receivedTransactions;
    } catch (e) {
      print('Error scanning for received transactions: $e');
      return [];
    }
  }

  /// Parse USDC amount from transaction input data
  BigInt _parseUSDCAmount(String input) {
    try {
      if (input.length < 74) {
        print('    Input data too short: ${input.length} < 74');
        return BigInt.zero; // Minimum length for transfer function
      }
      
      // USDC transfer function: transfer(address,uint256)
      // Function selector: 0xa9059cbb (4 bytes)
      // Address parameter: 32 bytes
      // Amount parameter: 32 bytes
      if (input.startsWith('0xa9059cbb')) {
        print('    Valid USDC transfer function detected');
        final amountHex = input.substring(74); // Skip function selector and address
        if (amountHex.length >= 64) {
          final amountHexClean = amountHex.substring(0, 64);
          final amount = BigInt.parse(amountHexClean, radix: 16);
          print('    Parsed amount: $amount (hex: $amountHexClean)');
          return amount;
        } else {
          print('    Amount hex too short: ${amountHex.length} < 64');
        }
      } else {
        print('    Not a USDC transfer function: ${input.substring(0, 10)}...');
      }
      return BigInt.zero;
    } catch (e) {
      print('    Error parsing USDC amount: $e');
      return BigInt.zero;
    }
  }

  /// Manually verify transaction status from blockchain
  Future<String> verifyTransactionStatus(String txHash) async {
    try {
      print('=== MANUALLY VERIFYING TRANSACTION STATUS ===');
      print('Transaction hash: $txHash');
      
      final receipt = await _client.getTransactionReceipt(txHash);
      if (receipt != null) {
        print('Receipt found!');
        print('Status: ${receipt.status}');
        print('Gas used: ${receipt.gasUsed}');
        print('Block number: ${receipt.blockNumber}');
        
        // receipt.status is a boolean: true = success, false = failure
        final status = receipt.status == true ? 'confirmed' : 'failed';
        print('Interpreted status: $status');
        
        // Update local transaction status if it exists
        updateLocalTransactionStatus(txHash, status);
        
        return status;
      } else {
        print('No receipt found - transaction might still be pending');
        return 'pending';
      }
    } catch (e) {
      print('Error verifying transaction status: $e');
      return 'error';
    }
  }

  /// Check transaction status from blockchain (for debugging)
  Future<Map<String, dynamic>?> checkTransactionStatus(String txHash) async {
    try {
      final receipt = await _client.getTransactionReceipt(txHash);
      if (receipt != null) {
        return {
          'hash': txHash,
          'status': receipt.status,
          'gasUsed': receipt.gasUsed?.toInt(),
          'blockNumber': receipt.blockNumber?.toString(),
          'isSuccess': receipt.status == true, // receipt.status is boolean
        };
      }
      return null;
    } catch (e) {
      print('Error checking transaction status: $e');
      return null;
    }
  }

  /// Wait for transaction confirmation
  Future<bool> waitForTransactionConfirmation(String txHash) async {
    try {
      int attempts = 0;
      const maxAttempts = 30; // Wait up to 5 minutes
      
      while (attempts < maxAttempts) {
        try {
          final receipt = await _client.getTransactionReceipt(txHash);
          if (receipt != null) {
            print('=== TRANSACTION RECEIPT DETAILS ===');
            print('Transaction hash: $txHash');
            print('Transaction status: ${receipt.status}');
            print('Gas used: ${receipt.gasUsed}');
            print('Block number: ${receipt.blockNumber}');
            print('Contract address: ${receipt.contractAddress?.hex}');
            print('Logs: ${receipt.logs.length}');
            
            // Check if transaction was successful
            // receipt.status is a boolean: true = success, false = failure
            final isSuccess = receipt.status == true;
            print('Transaction success: $isSuccess');
            print('Status interpretation: ${isSuccess ? "SUCCESS" : "FAILED"}');
            print('=====================================');
            
            return isSuccess;
          } else {
            print('Transaction receipt is null for hash: $txHash');
          }
        } catch (e) {
          print('Error checking transaction receipt: $e');
        }
        
        await Future.delayed(const Duration(seconds: 10));
        attempts++;
        print('Waiting for confirmation... Attempt $attempts/$maxAttempts');
      }
      
      print('Transaction confirmation timeout: $txHash');
      return false;
    } catch (e) {
      print('Error waiting for transaction confirmation: $e');
      return false;
    }
  }

  /// Get current gas price
  Future<BigInt> getGasPrice() async {
    try {
      final gasPrice = await _client.getGasPrice();
      return gasPrice.getInWei;
    } catch (e) {
      print('Error getting gas price: $e');
      // Return default gas price if query fails
      return BigInt.from(20000000000); // 20 Gwei
    }
  }

  /// Get estimated gas for USDC transfer
  static Future<BigInt> estimateGasForUSDCTransfer() async {
    try {
      // Standard gas estimation for ERC20 transfer
      return BigInt.from(65000); // Typical USDC transfer gas
    } catch (e) {
      print('Error estimating gas: $e');
      return BigInt.from(100000); // Default estimate
    }
  }

  /// Get transaction details by hash
  Future<Map<String, dynamic>?> getTransactionDetails(String txHash) async {
    try {
      // Check if wallet is initialized
      if (_walletAddress == null) {
        print('Wallet not initialized yet');
        return null;
      }
      
      final transaction = await _client.getTransactionByHash(txHash);
      if (transaction != null) {
        return {
          'hash': txHash,
          'from': transaction.from?.hex,
          'to': transaction.to?.hex,
          'value': transaction.value?.getInEther.toString(),
          'gas': transaction.gas?.toInt(),
          'gasPrice': transaction.gasPrice?.getInWei.toInt(),
          'nonce': transaction.nonce,
          'blockNumber': transaction.blockNumber != null ? transaction.blockNumber.toString() : null,
        };
      }
      return null;
    } catch (e) {
      print('Error getting transaction details: $e');
      return null;
    }
  }

  /// Save private key securely
  Future<void> _savePrivateKey(List<int> privateKeyBytes) async {
    if (privateKeyBytes.isEmpty) {
      print('No private key bytes to save');
      return;
    }
    _storedPrivateKey = privateKeyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Load private key from storage
  Future<String?> loadPrivateKey() async {
    if (_storedPrivateKey == null) {
      print('No private key stored yet');
      return null;
    }
    return _storedPrivateKey;
  }

  /// Get wallet mnemonic (for backup purposes)
  Future<String?> getWalletMnemonic() async {
    try {
      // This would need to be stored during wallet creation
      // For now, return null as we don't store it
      print('No mnemonic stored yet');
      return null;
    } catch (e) {
      print('Error getting mnemonic: $e');
      return null;
    }
  }

  /// Validate Ethereum address format
  static bool isValidAddress(String address) {
    try {
      if (!address.startsWith('0x') || address.length != 42) {
        return false;
      }
      EthereumAddress.fromHex(address);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get network information
  static Map<String, dynamic> getNetworkInfo() {
    return {
      'name': 'Base Sepolia Testnet',
      'chainId': _baseTestnetChainId,
      'rpcUrl': _baseTestnetRpc,
      'explorerUrl': 'https://sepolia.basescan.org',
      'usdcContract': _usdcContractAddress,
      'currency': 'ETH',
      'currencySymbol': 'ETH',
    };
  }

  /// Convert USDC amount to fiat currency
  static double convertUSDCToFiat(BigInt usdcAmount, String fiatCurrency) {
    final usdcValue = usdcAmount / BigInt.from(1000000); // USDC has 6 decimals
    final rate = _fiatRates[fiatCurrency] ?? 1.0;
    return usdcValue.toDouble() * rate;
  }

  /// Convert fiat amount to USDC
  static BigInt convertFiatToUSDC(double fiatAmount, String fiatCurrency) {
    final rate = _fiatRates[fiatCurrency] ?? 1.0;
    final usdcValue = fiatAmount / rate;
    return BigInt.from((usdcValue * 1000000).round()); // USDC has 6 decimals
  }

  /// Get available fiat currencies
  static List<String> getAvailableFiatCurrencies() {
    return _fiatRates.keys.toList();
  }

  /// Get estimated gas cost in fiat
  Future<double> getEstimatedGasCostInFiat(String fiatCurrency) async {
    try {
      final gasPrice = await getGasPrice();
      final estimatedGas = BigInt.from(100000); // Standard USDC transfer gas
      final gasCostInWei = gasPrice * estimatedGas;
      final gasCostInEth = gasCostInWei / BigInt.from(1000000000000000000); // Convert from wei to ETH
      
      // Mock ETH to USD rate (replace with real API)
      const ethToUsdRate = 2000.0;
      final gasCostInUsd = gasCostInEth.toDouble() * ethToUsdRate;
      
      // Convert to requested fiat currency
      return convertUSDCToFiat(BigInt.from((gasCostInUsd * 1000000).round()), fiatCurrency);
    } catch (e) {
      print('Error getting estimated gas cost: $e');
      return 0.0;
    }
  }

  /// Check if gas sponsorship is available
  bool isGasSponsorshipAvailable() {
    return _enableSponsoredGas;
  }

  /// Get transaction status from blockchain
  Future<String> getTransactionStatus(String txHash) async {
    try {
      // In a real implementation, you would query the blockchain for transaction status
      // For demo purposes, return a mock status
      await Future.delayed(const Duration(seconds: 1));
      return 'confirmed';
    } catch (e) {
      print('Error getting transaction status: $e');
      return 'unknown';
    }
  }

  /// Dispose resources
  void dispose() {
    try {
      _client.dispose();
      _relayerService.dispose();
    } catch (e) {
      print('Error disposing client: $e');
    }
  }
}

/// Transaction information model
class TransactionInfo {
  final String hash;
  final String from;
  final String to;
  final BigInt amount;
  final String type; // 'sent' or 'received'
  final DateTime timestamp;
  final String status;

  TransactionInfo({
    required this.hash,
    required this.from,
    required this.to,
    required this.amount,
    required this.type,
    required this.timestamp,
    required this.status,
  });

  factory TransactionInfo.fromJson(Map<String, dynamic> json) {
    return TransactionInfo(
      hash: json['hash'],
      from: json['from'],
      to: json['to'],
      amount: BigInt.parse(json['amount']),
      type: json['type'],
      timestamp: DateTime.parse(json['timestamp']),
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hash': hash,
      'from': from,
      'to': to,
      'amount': amount.toString(),
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
    };
  }
}
