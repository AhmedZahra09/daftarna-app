import 'package:flutter/material.dart';
import '../theme.dart';

class SummaryCard extends StatelessWidget {
  final int owedToMe;
  final int iOwe;

  const SummaryCard({
    super.key,
    required this.owedToMe,
    required this.iOwe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildItem('إجمالي الأموال لك', owedToMe, kGreen),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildItem('إجمالي المستحق عليك', iOwe, kRed),
        ],
      ),
    );
  }

  Widget _buildItem(String title, int amount, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 6),
        Text(
          '${fmt(amount)} د.س',
          style: TextStyle(
            color: color == kGreen ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
