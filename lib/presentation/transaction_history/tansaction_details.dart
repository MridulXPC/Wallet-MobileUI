// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';

// class TransactionDetailsScreen extends StatelessWidget {
//   final Map<String, dynamic> transaction;

//   const TransactionDetailsScreen({Key? key, required this.transaction}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF0B0D1A),
//       appBar: AppBar(
//         backgroundColor: const Color(0xFF0B0D1A),
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: const Text(
//           'Transaction details',
//           style: TextStyle(
//             color: Colors.white,
//             fontSize: 18,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//         centerTitle: true,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Transaction Type Title
//             Text(
//               _getTransactionTitle(),
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 32,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
            
//             const SizedBox(height: 8),
            
//             // Date and Time
//             Text(
//               transaction['dateTime'],
//               style: const TextStyle(
//                 color: Color(0xFF6B7280),
//                 fontSize: 14,
//               ),
//             ),
            
//             const SizedBox(height: 16),
            
//             // Status Badge
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//               decoration: BoxDecoration(
//                 color: _getStatusColor(),
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: Text(
//                 transaction['status'],
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 12,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
            
//             const SizedBox(height: 24),
            
//             // Amount with Icon
//             Row(
//               children: [
//                 Container(
//                   width: 24,
//                   height: 24,
//                   decoration: BoxDecoration(
//                     color: _getCoinColor(),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Center(
//                     child: Text(
//                       transaction['coinIcon'],
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 12,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Text(
//                   '${transaction['amount']} ${transaction['coin']}',
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 20,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//                 if (transaction['coin'] == 'BTC LIGHTNING') ...[
//                   const SizedBox(width: 8),
//                   Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//                     decoration: BoxDecoration(
//                       color: Colors.purple,
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     child: const Text(
//                       'Lightning',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 10,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                 ],
//               ],
//             ),
            
//             const SizedBox(height: 32),
            
//             // Transaction Details Section
//             const Text(
//               'Transaction details',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 16,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
            
//             const SizedBox(height: 16),
            
//             // Transaction Details Items
//             if (transaction['type'] == 'swap') ...[
//               _buildSwapDetails(),
//             ] else ...[
//               _buildTransactionDetailItem('Block', transaction['block']?.toString() ?? '-'),
//               _buildTransactionDetailItem('To', transaction['to'] ?? '-'),
//               _buildTransactionDetailItem('From', transaction['from'] ?? '-'),
//               _buildTransactionDetailItem('Hash', transaction['hash'] ?? '-'),
//             ],
            
//             // Lightning Details (if applicable)
//             if (transaction['coin'] == 'BTC LIGHTNING' && transaction['lightningDetails'] != null) ...[
//               const SizedBox(height: 32),
//               Row(
//                 children: [
//                   const Icon(Icons.flash_on, color: Colors.purple, size: 16),
//                   const SizedBox(width: 8),
//                   const Text(
//                     'Lightning details',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 16,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 16),
//               ...transaction['lightningDetails'].entries.map<Widget>((entry) {
//                 return _buildTransactionDetailItem(entry.key, entry.value?.toString() ?? '-');
//               }).toList(),
//             ],
            
//             // Fee Details
//             if (transaction['feeDetails'] != null) ...[
//               const SizedBox(height: 32),
//               const Text(
//                 'Fee Details',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//               const SizedBox(height: 16),
//               ...transaction['feeDetails'].entries.map<Widget>((entry) {
//                 return _buildTransactionDetailItem(entry.key, entry.value?.toString() ?? '-');
//               }).toList(),
//             ],
            
//             const SizedBox(height: 100),
//           ],
//         ),
//       ),
//     );
//   }
  
//   String _getTransactionTitle() {
//     switch (transaction['type']) {
//       case 'send':
//         return 'Send';
//       case 'receive':
//         return 'Received';
//       case 'swap':
//         return 'Swap';
//       default:
//         return 'Transaction';
//     }
//   }
  
//   Color _getStatusColor() {
//     switch (transaction['status'].toLowerCase()) {
//       case 'confirmed':
//         return Colors.green;
//       case 'pending':
//         return Colors.orange;
//       case 'failed':
//         return Colors.red;
//       default:
//         return Colors.grey;
//     }
//   }
  
//   Color _getCoinColor() {
//     switch (transaction['coin']) {
//       case 'BTC':
//       case 'BTC LIGHTNING':
//         return Colors.orange;
//       case 'ETH':
//         return Colors.blue;
//       case 'XRP':
//         return Colors.blue.shade800;
//       case 'ADA':
//         return Colors.blue.shade600;
//       case 'USDT':
//         return Colors.green;
//       default:
//         return const Color(0xFF2A2D3A);
//     }
//   }
  
//   Widget _buildSwapDetails() {
//     final swapDetails = transaction['swapDetails'] as Map<String, dynamic>;
//     return Column(
//       children: [
//         _buildTransactionDetailItem('From', '${swapDetails['fromAmount']} ${swapDetails['fromCoin']}'),
//         _buildTransactionDetailItem('To', '${swapDetails['toAmount']} ${swapDetails['toCoin']}'),
//         _buildTransactionDetailItem('Exchange Rate', '1 ${swapDetails['fromCoin']} = ${swapDetails['rate']} ${swapDetails['toCoin']}'),
//         _buildTransactionDetailItem('Swap ID', swapDetails['swapId']),
//         _buildTransactionDetailItem('Hash', transaction['hash'] ?? '-'),
//       ],
//     );
//   }
  
//   Widget _buildTransactionDetailItem(String label, String value) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 16),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             label,
//             style: const TextStyle(
//               color: Color(0xFF6B7280),
//               fontSize: 14,
//             ),
//           ),
//           const SizedBox(width: 16),
//           Expanded(
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.end,
//               children: [
//                 Flexible(
//                   child: Text(
//                     value,
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 14,
//                     ),
//                     textAlign: TextAlign.end,
//                   ),
//                 ),
//                 if (value != '-' && value.length > 20) ...[
//                   const SizedBox(width: 8),
//                   GestureDetector(
//                     onTap: () {
//                       Clipboard.setData(ClipboardData(text: value));
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         const SnackBar(
//                           content: Text('Copied to clipboard'),
//                           duration: Duration(seconds: 2),
//                         ),
//                       );
//                     },
//                     child: const Icon(
//                       Icons.copy,
//                       color: Color(0xFF6B7280),
//                       size: 16,
//                     ),
//                   ),
//                 ],
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }