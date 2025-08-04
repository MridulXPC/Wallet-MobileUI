import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../theme/app_theme.dart';

class AboutSectionWidget extends StatefulWidget {
  final Map<String, dynamic> tokenData;

  const AboutSectionWidget({
    super.key,
    required this.tokenData,
  });

  @override
  State<AboutSectionWidget> createState() => _AboutSectionWidgetState();
}

class _AboutSectionWidgetState extends State<AboutSectionWidget> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final String aboutText = _getAboutText();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.darkTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About ${widget.tokenData["name"]}',
            style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2.h),

          AnimatedCrossFade(
            firstChild: Text(
              aboutText.length > 150
                  ? '${aboutText.substring(0, 150)}...'
                  : aboutText,
              style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            secondChild: Text(
              aboutText,
              style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),

          if (aboutText.length > 150) ...[
            SizedBox(height: 1.h),
            GestureDetector(
              onTap: () {
                setState(() {
                  isExpanded = !isExpanded;
                });
              },
              child: Text(
                isExpanded ? 'Show less' : 'Read more',
                style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.info,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          SizedBox(height: 3.h),

          // Token Stats
          _buildTokenStats(),
        ],
      ),
    );
  }

  Widget _buildTokenStats() {
    return Column(
      children: [
        _buildStatRow('Market Cap', '\$2.4B'),
        SizedBox(height: 2.h),
        _buildStatRow('24h Volume', '\$45.2M'),
        SizedBox(height: 2.h),
        _buildStatRow(
            'Circulating Supply', '1.2B ${widget.tokenData["symbol"]}'),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
            color: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _getAboutText() {
    final symbol = widget.tokenData["symbol"] as String;

    switch (symbol) {
      case 'BTC':
        return 'Bitcoin is a decentralized cryptocurrency that was first described in a 2008 whitepaper published by a person or group of people using the alias Satoshi Nakamoto. It was launched soon after, in January 2009. Bitcoin is a peer-to-peer online currency, meaning that all transactions happen directly between equal, independent network participants, without the need for any intermediary to permit or facilitate them.';
      case 'ETH':
        return 'Ethereum is a decentralized, open-source blockchain with smart contract functionality. Ether is the native cryptocurrency of the platform. Among cryptocurrencies, Ether is second only to Bitcoin in market capitalization. Ethereum was conceived in 2013 by programmer Vitalik Buterin.';
      case 'ADA':
        return 'Cardano is a proof-of-stake blockchain platform that says its goal is to allow "changemakers, innovators and visionaries" to bring about positive global change. The open-source project also aims to "redistribute power from unaccountable structures to the margins to individuals" — helping to create a society that is more secure, transparent and fair.';
      default:
        return 'This cryptocurrency is part of the decentralized finance ecosystem, designed to provide innovative financial solutions and opportunities for users worldwide. It operates on blockchain technology to ensure security, transparency, and decentralization.';
    }
  }
}
