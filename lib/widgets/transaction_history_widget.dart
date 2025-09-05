import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../config/app_config.dart';

/// Extension to capitalize first letter of string
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

/// Widget for displaying transaction history
class TransactionHistoryWidget extends StatelessWidget {
  const TransactionHistoryWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, child) {
        final transactions = walletProvider.recentTransactions;
        
        if (transactions.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppConfig.darkCard,
              borderRadius: BorderRadius.circular(AppConfig.borderRadius),
              border: Border.all(
                color: AppConfig.darkBorder,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.history,
                  color: AppConfig.darkTextSecondary,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'No transactions yet',
                  style: TextStyle(
                    color: AppConfig.darkTextSecondary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your transaction history will appear here',
                  style: TextStyle(
                    color: AppConfig.darkTextSecondary,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: AppConfig.darkCard,
            borderRadius: BorderRadius.circular(AppConfig.borderRadius),
            border: Border.all(
              color: AppConfig.darkBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.history,
                      color: AppConfig.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Recent Transactions',
                      style: TextStyle(
                        color: AppConfig.darkText,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => walletProvider.refreshWallet(),
                      child: Text(
                        'Refresh',
                        style: TextStyle(
                          color: AppConfig.primaryColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () async {
                        // Manually verify all transaction statuses
                        for (final tx in walletProvider.transactions) {
                          if (tx['hash'] != null) {
                            await walletProvider.verifyTransactionStatus(tx['hash']);
                          }
                        }
                        // Refresh the wallet to update the UI
                        walletProvider.refreshWallet();
                      },
                      icon: Icon(
                        Icons.verified,
                        color: AppConfig.accentColor,
                        size: 20,
                      ),
                      tooltip: 'Verify transaction statuses',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppConfig.darkBorder),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final transaction = transactions[index];
                  return _buildTransactionItem(transaction, context);
                },
              ),
              if (walletProvider.transactions.length > 4)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/transaction-history');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConfig.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppConfig.borderRadius),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      ),
                      child: Text(
                        'View All ${walletProvider.transactions.length} Transactions',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction, BuildContext context) {
    final type = transaction['type'] as String;
    final amount = transaction['amount'] as String;
    final hash = transaction['hash'] as String;
    final status = transaction['status'] as String;
    final timestamp = DateTime.fromMillisecondsSinceEpoch(transaction['timestamp'] as int);
    final isSend = type == 'send';
    
    // Parse amount for display
    final amountValue = BigInt.tryParse(amount) ?? BigInt.zero;
    final displayAmount = (amountValue / BigInt.from(1000000)).toStringAsFixed(2);
    
    return GestureDetector(
      onTap: () => _showTransactionDetails(context, transaction),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Transaction type icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSend 
                    ? AppConfig.errorColor.withOpacity(0.1)
                    : AppConfig.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isSend ? Icons.arrow_upward : Icons.arrow_downward,
                color: isSend ? AppConfig.errorColor : AppConfig.successColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            
            // Transaction details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isSend ? 'Sent' : 'Received',
                        style: const TextStyle(
                          color: AppConfig.darkText,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${isSend ? '-' : '+'}\$$displayAmount USDC',
                        style: TextStyle(
                          color: isSend ? AppConfig.errorColor : AppConfig.successColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        isSend ? 'To: ' : 'From: ',
                        style: TextStyle(
                          color: AppConfig.darkTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _formatAddress(isSend ? transaction['to'] : transaction['from']),
                          style: TextStyle(
                            color: AppConfig.darkTextSecondary,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _formatTimestamp(timestamp),
                        style: TextStyle(
                          color: AppConfig.darkTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: _getStatusColor(status),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Copy hash button
            IconButton(
              onPressed: () => _copyTransactionHash(hash, context),
              icon: Icon(
                Icons.copy,
                color: AppConfig.darkTextSecondary,
                size: 18,
              ),
              tooltip: 'Copy transaction hash',
            ),
          ],
        ),
      ),
    );
  }

  String _formatAddress(String address) {
    if (address.length < 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return AppConfig.successColor;
      case 'pending':
        return AppConfig.warningColor;
      case 'failed':
        return AppConfig.errorColor;
      default:
        return Colors.grey;
    }
  }

  void _copyTransactionHash(String hash, BuildContext context) {
    Clipboard.setData(ClipboardData(text: hash));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Transaction hash copied: ${hash.substring(0, 10)}...'),
        backgroundColor: AppConfig.primaryColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showTransactionDetails(BuildContext context, Map<String, dynamic> transaction) {
    final type = transaction['type'] as String;
    final amount = transaction['amount'] as String;
    final hash = transaction['hash'] as String;
    final status = transaction['status'] as String;
    final timestamp = DateTime.fromMillisecondsSinceEpoch(transaction['timestamp'] as int);
    final isSend = type == 'send';
    
    // Parse amount for display
    final amountValue = BigInt.tryParse(amount) ?? BigInt.zero;
    final displayAmount = (amountValue / BigInt.from(1000000)).toStringAsFixed(2);
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppConfig.darkCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSend 
                      ? AppConfig.errorColor.withOpacity(0.1)
                      : AppConfig.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isSend ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isSend ? AppConfig.errorColor : AppConfig.successColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Transaction Details',
                style: TextStyle(
                  color: AppConfig.darkText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Amount Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSend 
                        ? AppConfig.errorColor.withOpacity(0.1)
                        : AppConfig.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${isSend ? '-' : '+'}\$$displayAmount USDC',
                        style: TextStyle(
                          color: isSend ? AppConfig.errorColor : AppConfig.successColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isSend ? 'Sent' : 'Received',
                        style: TextStyle(
                          color: AppConfig.darkTextSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Transaction Details
                _buildDetailRow('Status', status.toUpperCase(), _getStatusColor(status)),
                _buildDetailRow('Type', type.capitalize(), AppConfig.darkText),
                _buildDetailRow('Date', _formatDetailedTimestamp(timestamp), AppConfig.darkText),
                _buildDetailRow('Time', _formatDetailedTime(timestamp), AppConfig.darkText),
                
                const SizedBox(height: 16),
                
                // Address Details
                _buildDetailRow(
                  'From', 
                  _formatAddress(transaction['from'] as String),
                  AppConfig.darkText,
                  canCopy: true,
                  onCopy: () => _copyToClipboard(context, transaction['from'] as String, 'From address'),
                ),
                _buildDetailRow(
                  'To', 
                  _formatAddress(transaction['to'] as String),
                  AppConfig.darkText,
                  canCopy: true,
                  onCopy: () => _copyToClipboard(context, transaction['to'] as String, 'To address'),
                ),
                
                const SizedBox(height: 16),
                
                // Transaction Hash
                _buildDetailRow(
                  'Transaction Hash', 
                  _formatAddress(hash),
                  AppConfig.darkText,
                  canCopy: true,
                  onCopy: () => _copyToClipboard(context, hash, 'Transaction hash'),
                ),
                
                if (!AppConfig.enableWaaS) ...[
                  if (transaction['gasUsed'] != null) ...[
                    const SizedBox(height: 16),
                    _buildDetailRow('Gas Used', transaction['gasUsed'].toString(), AppConfig.darkText),
                  ],
                  if (transaction['gasPrice'] != null) ...[
                    _buildDetailRow('Gas Price', transaction['gasPrice'].toString(), AppConfig.darkText),
                  ],
                ],
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Close',
                style: TextStyle(
                  color: AppConfig.darkTextSecondary,
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _copyTransactionHash(hash, context);
                Navigator.of(dialogContext).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Copy Hash'),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildDetailRow(String label, String value, Color valueColor, {bool canCopy = false, VoidCallback? onCopy}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: AppConfig.darkTextSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: valueColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: label.contains('Hash') || label.contains('address') ? 'monospace' : null,
                    ),
                  ),
                ),
                if (canCopy && onCopy != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onCopy,
                    icon: Icon(
                      Icons.copy,
                      color: AppConfig.primaryColor,
                      size: 16,
                    ),
                    tooltip: 'Copy $label',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDetailedTimestamp(DateTime timestamp) {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
  
  String _formatDetailedTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
  
  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: AppConfig.successColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
