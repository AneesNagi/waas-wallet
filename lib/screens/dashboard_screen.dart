import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/transaction_history_widget.dart';
import '../config/app_config.dart';
import 'package:flutter/foundation.dart'; // Added for kDebugMode

class DashboardScreen extends StatefulWidget {
  final Function(int)? onTabChange;
  
  const DashboardScreen({super.key, this.onTabChange});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh wallet data when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().refreshWallet();
    });
  }

  void _copyAddress() {
    final walletProvider = context.read<WalletProvider>();
    if (walletProvider.walletAddress != null) {
      Clipboard.setData(ClipboardData(text: walletProvider.walletAddress!));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Wallet address copied to clipboard'),
          backgroundColor: AppConfig.successColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _navigateToTab(int index) {
    // Use callback to communicate with parent home screen
    if (widget.onTabChange != null) {
      widget.onTabChange!(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<WalletProvider, ThemeProvider>(
      builder: (context, walletProvider, themeProvider, child) {
        if (walletProvider.isLoading) {
          return Scaffold(
            backgroundColor: themeProvider.getBackgroundColor(),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppConfig.primaryColor),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Loading Wallet...',
                    style: TextStyle(
                      color: themeProvider.getTextColor(),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (walletProvider.errorMessage != null) {
          return _buildErrorView(walletProvider, themeProvider);
        }

        return Scaffold(
          backgroundColor: themeProvider.getBackgroundColor(),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with Theme Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Wallet',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.getTextColor(),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Manage your USDC',
                            style: TextStyle(
                              fontSize: 16,
                              color: themeProvider.getSecondaryTextColor(),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // Theme Toggle Button
                          Container(
                            decoration: BoxDecoration(
                              color: themeProvider.getCardColor(),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: themeProvider.getBorderColor(),
                                width: 1,
                              ),
                            ),
                            child: IconButton(
                              onPressed: () => themeProvider.toggleTheme(),
                              icon: Icon(
                                themeProvider.isDarkMode 
                                    ? Icons.light_mode 
                                    : Icons.dark_mode,
                                color: AppConfig.primaryColor,
                                size: 24,
                              ),
                              tooltip: 'Toggle theme',
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Network Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppConfig.gradientStart,
                                  AppConfig.gradientMiddle,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppConfig.primaryColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              walletProvider.networkName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Balance Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppConfig.gradientStart,
                          AppConfig.gradientMiddle,
                          AppConfig.gradientEnd,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppConfig.primaryColor.withOpacity(0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'USDC',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Total Balance',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              '\$',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              walletProvider.formattedUSDCBalance,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 52,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.fingerprint,
                                color: Colors.white.withOpacity(0.8),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  walletProvider.shortWalletAddress,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _copyAddress,
                                icon: Icon(
                                  Icons.copy,
                                  color: Colors.white.withOpacity(0.8),
                                  size: 20,
                                ),
                                tooltip: 'Copy address',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (!AppConfig.enableWaaS)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: themeProvider.getCardColor(),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: themeProvider.getBorderColor(),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppConfig.warningColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.currency_bitcoin,
                              color: AppConfig.warningColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ETH Balance',
                                  style: TextStyle(
                                    color: themeProvider.getSecondaryTextColor(),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${walletProvider.formattedETHBalance} ETH',
                                  style: TextStyle(
                                    color: themeProvider.getTextColor(),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'For gas fees on Base Network',
                                  style: TextStyle(
                                    color: themeProvider.getSecondaryTextColor(),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (AppConfig.enableWaaS)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: themeProvider.getCardColor(),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: themeProvider.getBorderColor(),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppConfig.successColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.local_gas_station,
                              color: AppConfig.successColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Gas Sponsored',
                                  style: TextStyle(
                                    color: themeProvider.getSecondaryTextColor(),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Network fees are covered by the relayer',
                                  style: TextStyle(
                                    color: themeProvider.getTextColor(),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 32),
                  
                  // Quick Actions
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      color: themeProvider.getTextColor(),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.send,
                          label: 'Send',
                          color: AppConfig.primaryColor,
                          onTap: () => _navigateToTab(1),
                          themeProvider: themeProvider,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.qr_code_scanner,
                          label: 'Receive',
                          color: AppConfig.accentColor,
                          onTap: () => _navigateToTab(2),
                          themeProvider: themeProvider,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Transaction History
                  const TransactionHistoryWidget(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorView(WalletProvider walletProvider, ThemeProvider themeProvider) {
    return Scaffold(
      backgroundColor: themeProvider.getBackgroundColor(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: AppConfig.errorColor,
                size: 64,
              ),
              const SizedBox(height: 24),
              Text(
                'Wallet Error',
                style: TextStyle(
                  color: themeProvider.getTextColor(),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                walletProvider.errorMessage ?? 'Unknown error occurred',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: themeProvider.getSecondaryTextColor(),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => walletProvider.refreshWallet(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required ThemeProvider themeProvider,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: themeProvider.getCardColor(),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: themeProvider.getBorderColor(),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: TextStyle(
                color: themeProvider.getTextColor(),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
