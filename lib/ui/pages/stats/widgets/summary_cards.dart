import 'package:flutter/material.dart';
import 'package:mytime/core/constants/app_colors.dart';

/// Three summary stat cards displayed at the top of the stats page.
class SummaryCards extends StatelessWidget {
  final String todayTotal;
  final String weekTotal;
  final String avgPerDay;
  final String todayChange;
  final String weekChange;
  final String avgChange;

  const SummaryCards({
    super.key,
    required this.todayTotal,
    required this.weekTotal,
    required this.avgPerDay,
    this.todayChange = '+0%',
    this.weekChange = '+0%',
    this.avgChange = '+0%',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _StatCard(label: '今日', value: todayTotal, change: todayChange),
          const SizedBox(width: 6),
          _StatCard(label: '本周', value: weekTotal, change: weekChange),
          const SizedBox(width: 6),
          _StatCard(label: '日均', value: avgPerDay, change: avgChange),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String change;

  const _StatCard({required this.label, required this.value, required this.change});

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
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(change, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: positive ? AppColors.success : AppColors.danger)),
          ],
        ),
      ),
    );
  }
}
