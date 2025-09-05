import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../config/app_config.dart';

/// Widget for displaying gas sponsorship options and status
class GasSponsorshipWidget extends StatefulWidget {
  const GasSponsorshipWidget({super.key});

  @override
  State<GasSponsorshipWidget> createState() => _GasSponsorshipWidgetState();
}

class _GasSponsorshipWidgetState extends State<GasSponsorshipWidget> {
  bool _isCheckingStatus = false;
  Map<String, dynamic>? _sponsorshipStatus;

  @override
  void initState() {
    super.initState();
    _checkSponsorshipStatus();
  }

  Future<void> _checkSponsorshipStatus() async {
    setState(() {
      _isCheckingStatus = true;
    });

    try {
      // In a real implementation, you'd check the actual relayer status
      // For demo purposes, simulate a status check
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _sponsorshipStatus = {
          'available': true,
          'relayer': 'Base Gas Station',
          'status': 'Active',
          'gasPrice': '0 Gwei',
          'dailyLimit': '100 transactions',
        };
        _isCheckingStatus = false;
      });
    } catch (e) {
      setState(() {
        _sponsorshipStatus = {
          'available': false,
          'error': e.toString(),
        };
        _isCheckingStatus = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppConfig.darkSurface,
            borderRadius: BorderRadius.circular(AppConfig.borderRadius),
            border: Border.all(
              color: Colors.grey.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_gas_station,
                    color: AppConfig.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Gas Sponsorship',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: walletProvider.useSponsoredGas,
                    onChanged: walletProvider.isGasSponsorshipAvailable
                        ? (value) => walletProvider.toggleGasSponsorship()
                        : null,
                    activeColor: AppConfig.primaryColor,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Sponsorship Status
              if (_isCheckingStatus)
                const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                )
              else if (_sponsorshipStatus != null)
                _buildStatusInfo()
              else
                const Text(
                  'Unable to check sponsorship status',
                  style: TextStyle(color: Colors.grey),
                ),
              
              const SizedBox(height: 16),
              
              // Information
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppConfig.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppConfig.primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppConfig.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        walletProvider.useSponsoredGas
                            ? 'Gas fees will be covered by the relayer. You only pay for the USDC transfer amount.'
                            : 'You will pay for gas fees using your ETH balance.',
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusInfo() {
    final status = _sponsorshipStatus!;
    
    if (status['available'] == true) {
      return Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: AppConfig.successColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Available via ${status['relayer']}',
                style: TextStyle(
                  color: AppConfig.successColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildStatusRow('Status', status['status']),
          _buildStatusRow('Gas Price', status['gasPrice']),
          _buildStatusRow('Daily Limit', status['dailyLimit']),
        ],
      );
    } else {
      return Row(
        children: [
          Icon(
            Icons.error_outline,
            color: AppConfig.errorColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Not available: ${status['error'] ?? 'Unknown error'}',
              style: TextStyle(
                color: AppConfig.errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
