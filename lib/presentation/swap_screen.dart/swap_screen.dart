import 'package:cryptowallet/theme/app_theme.dart';
import 'package:cryptowallet/widgets/custom_icon_widget.dart';
import 'package:flutter/material.dart';

class CryptoSwapScreen extends StatefulWidget {
  const CryptoSwapScreen({super.key});

  @override
  State<CryptoSwapScreen> createState() => _CryptoSwapScreenState();
}
  bool isHighContrast = false;
class _CryptoSwapScreenState extends State<CryptoSwapScreen> {

    String fromCoin = 'BTC';
  String toCoin = 'ETH';

  void _swapCoins() {
    setState(() {
      final temp = fromCoin;
      fromCoin = toCoin;
      toCoin = temp;
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: CustomIconWidget(
            iconName: 'close',
            color: AppTheme.darkTheme.colorScheme.onSurface,
            size: 24,
          ),
        ),
        title: Text(
          'Swap',
          style: AppTheme.darkTheme.textTheme.titleLarge,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                isHighContrast = !isHighContrast;
              });
            },
            icon: CustomIconWidget(
              iconName: 'contrast',
              color: AppTheme.darkTheme.colorScheme.onSurface,
              size: 24,
            ),
          ),
        ],
      ),

  body:     Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: [
              SizedBox(height: 50),
              Text('I have 0 $fromCoin', style: TextStyle(color: Colors.grey)),
              SizedBox(height: 10),
              _buildCoinSelector(fromCoin),
              SizedBox(height: 10),
              Text('0 $fromCoin', style: TextStyle(color: Colors.grey)),
              Text('\$0', style: TextStyle(color: Colors.grey, fontSize: 22)),
              SizedBox(height: 20),
              IconButton(
                icon: Icon(Icons.swap_vert, color: Colors.white),
                onPressed: _swapCoins,
              ),
              SizedBox(height: 20),
              Text('I want $toCoin', style: TextStyle(color: Colors.grey)),
              SizedBox(height: 10),
              _buildCoinSelector(toCoin),
              SizedBox(height: 10),
              Text('0 $toCoin', style: TextStyle(color: Colors.grey)),
              Text('\$0', style: TextStyle(color: Colors.grey, fontSize: 22)),
              SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['MIN', 'HALF', 'MAX'].map((label) => _buildAmountButton(label)).toList(),
              ),
              Spacer(),
              Text(
                'Swap services are available through\nthird-party API providers.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),

            ],
          ),
        ),
    );
  }


    Widget _buildCoinSelector(String coin) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF2A2743),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hexagon, color: Colors.white),
          SizedBox(width: 8),
          Text(coin, style: TextStyle(color: Colors.white, fontSize: 16)),
          Icon(Icons.arrow_drop_down, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildAmountButton(String label) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      decoration: BoxDecoration(
        color: Color(0xFF2A2743),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(label, style: TextStyle(color: Colors.white)),
    );
  }


}