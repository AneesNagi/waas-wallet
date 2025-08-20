import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Transaction History',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.filter_list,
              size: 24.sp,
            ),
            onPressed: () {
              // TODO: Implement filter
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Tabs
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              child: Row(
                children: [
                  Expanded(
                    child: _buildFilterTab('All', true),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildFilterTab('Sent', false),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildFilterTab('Received', false),
                  ),
                ],
              ),
            ),
            
            // Transaction List
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                children: [
                  _buildTransactionItem(
                    type: 'Sent',
                    amount: '-150.00 USDC',
                    address: '0x1234...5678',
                    time: '2 hours ago',
                    status: 'Completed',
                    isSent: true,
                    txHash: '0xabcd...efgh',
                  ),
                  _buildTransactionItem(
                    type: 'Received',
                    amount: '+500.00 USDC',
                    address: '0x8765...4321',
                    time: '1 day ago',
                    status: 'Completed',
                    isSent: false,
                    txHash: '0xijkl...mnop',
                  ),
                  _buildTransactionItem(
                    type: 'Sent',
                    amount: '-75.50 USDC',
                    address: '0x9876...5432',
                    time: '3 days ago',
                    status: 'Completed',
                    isSent: true,
                    txHash: '0xqrst...uvwx',
                  ),
                  _buildTransactionItem(
                    type: 'Received',
                    amount: '+200.00 USDC',
                    address: '0x5432...1098',
                    time: '1 week ago',
                    status: 'Completed',
                    isSent: false,
                    txHash: '0xyzaa...bcde',
                  ),
                  _buildTransactionItem(
                    type: 'Sent',
                    amount: '-25.00 USDC',
                    address: '0x1111...2222',
                    time: '2 weeks ago',
                    status: 'Completed',
                    isSent: true,
                    txHash: '0xffff...gggg',
                  ),
                  _buildTransactionItem(
                    type: 'Received',
                    amount: '+1000.00 USDC',
                    address: '0x3333...4444',
                    time: '1 month ago',
                    status: 'Completed',
                    isSent: false,
                    txHash: '0xhhhh...iiii',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String label, bool isActive) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF0052FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: isActive ? const Color(0xFF0052FF) : Colors.grey[600]!,
          width: 1,
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.grey[400],
          fontSize: 14.sp,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildTransactionItem({
    required String type,
    required String amount,
    required String address,
    required String time,
    required String status,
    required bool isSent,
    required String txHash,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2330),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // TODO: Navigate to transaction details
          },
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: isSent 
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isSent ? Icons.arrow_upward : Icons.arrow_downward,
                        color: isSent ? Colors.red : Colors.green,
                        size: 16.sp,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            address,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[400],
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          amount,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: isSent ? Colors.red : Colors.green,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                SizedBox(height: 12.h),
                
                // Transaction Details Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Base Network',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: const Color(0xFF0052FF),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: const Color(0xFF0052FF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
