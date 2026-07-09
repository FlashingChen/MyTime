import 'package:flutter/material.dart';
import 'package:mytime/core/constants/app_colors.dart';

/// Animated circular progress timer with central time display.
class TimerCircle extends StatelessWidget {
  final Duration duration;
  final double progress;
  final bool animating;

  const TimerCircle({
    super.key,
    required this.duration,
    required this.progress,
    this.animating = true,
  });

  String _formatTime(Duration d) {
    final totalSec = d.inSeconds;
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    final s = totalSec % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    const size = 220.0;
    const strokeWidth = 6.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(size, size),
            painter: _RingPainter(
              color: const Color(0xFFE8E8ED),
              strokeWidth: strokeWidth,
              progress: 1,
            ),
          ),
          CustomPaint(
            size: const Size(size, size),
            painter: _RingPainter(
              gradient: const LinearGradient(
                colors: [AppColors.accentStart, AppColors.accentEnd],
              ),
              strokeWidth: strokeWidth,
              progress: progress.clamp(0.0, 1.0),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _formatTime(duration),
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -1.5,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '正在计时',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Color? color;
  final Gradient? gradient;
  final double strokeWidth;
  final double progress;

  _RingPainter({this.color, this.gradient, required this.strokeWidth, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (gradient != null) {
      paint.shader = gradient!.createShader(rect);
    } else {
      paint.color = color ?? const Color(0xFFE8E8ED);
    }

    canvas.drawArc(rect, -3.14159 / 2, 3.14159 * 2 * progress, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return progress != oldDelegate.progress;
  }
}
