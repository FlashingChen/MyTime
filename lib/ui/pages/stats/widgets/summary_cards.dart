import 'package:flutter/material.dart';
import 'package:mytime/core/constants/app_colors.dart';

/// Three summary stat cards displayed at the top of the stats page.
class SummaryCards extends StatelessWidget {
  final String label1;
  final String label2;
  final String label3;
  final String value1;
  final String value2;
  final String value3;
  final String change1;
  final String change2;
  final String change3;

  const SummaryCards({
    super.key,
    required this.value1,
    required this.value2,
    required this.value3,
    this.label1 = '今日',
    this.label2 = '本周',
    this.label3 = '日均',
    this.change1 = '+0%',
    this.change2 = '+0%',
    this.change3 = '+0%',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _StatCard(label: label1, value: value1, change: change1),
          const SizedBox(width: 6),
          _StatCard(label: label2, value: value2, change: change2),
          const SizedBox(width: 6),
          _StatCard(label: label3, value: value3, change: change3),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String change;

  const _StatCard({
    required this.label,
    required this.value,
    required this.change,
  });

  @override
  Widget build(BuildContext context) {
    final positive = !change.startsWith('-');
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 3)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              change,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: positive ? AppColors.success : AppColors.danger,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
