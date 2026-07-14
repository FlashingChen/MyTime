import 'package:flutter/material.dart';

/// SVG icon widgets used throughout the app.
/// All icons are drawn with CustomPainter to avoid emoji usage.
class SvgIcons {
  SvgIcons._();

  static Widget play({double size = 24, Color? color}) {
    return CustomPaint(
      size: Size(size, size),
      painter: _PlayPainter(color: color ?? Colors.white),
    );
  }

  static Widget stop({double size = 20, Color? color}) {
    return CustomPaint(
      size: Size(size, size),
      painter: _StopPainter(color: color ?? Colors.white),
    );
  }

  static Widget check({double size = 18, Color? color}) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CheckPainter(color: color ?? Colors.white),
    );
  }

  static Widget home({double size = 22, Color? color}) {
    return CustomPaint(
      size: Size(size, size),
      painter: _HomePainter(color: color ?? const Color(0xFF86868B)),
    );
  }

  static Widget timeline({double size = 22, Color? color}) {
    return CustomPaint(
      size: Size(size, size),
      painter: _TimelinePainter(color: color ?? const Color(0xFF86868B)),
    );
  }

  static Widget stats({double size = 22, Color? color}) {
    return CustomPaint(
      size: Size(size, size),
      painter: _StatsPainter(color: color ?? const Color(0xFF86868B)),
    );
  }

  static Widget profile({double size = 22, Color? color}) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ProfilePainter(color: color ?? const Color(0xFF86868B)),
    );
  }

  static Widget sparkle({double size = 20, Color? color}) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SparklePainter(color: color ?? const Color(0xFFA5B4FC)),
    );
  }

  static Widget chevronRight({double size = 18, Color? color}) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ChevronRightPainter(color: color ?? const Color(0xFFC7C7CC)),
    );
  }

  static Widget chevronLeft({double size = 18, Color? color}) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ChevronLeftPainter(color: color ?? const Color(0xFFC7C7CC)),
    );
  }

  static Widget add({double size = 24, Color? color}) {
    return CustomPaint(
      size: Size(size, size),
      painter: _AddPainter(color: color ?? const Color(0xFF1A1A2E)),
    );
  }

  static Widget edit({double size = 18, Color? color}) {
    return CustomPaint(
      size: Size(size, size),
      painter: _EditPainter(color: color ?? const Color(0xFF86868B)),
    );
  }

  static Widget delete({double size = 18, Color? color}) {
    return CustomPaint(
      size: Size(size, size),
      painter: _DeletePainter(color: color ?? const Color(0xFFEF4444)),
    );
  }
}

class _PlayPainter extends CustomPainter {
  final Color color;
  _PlayPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(size.width * 0.3, size.height * 0.15);
    path.lineTo(size.width * 0.85, size.height * 0.5);
    path.lineTo(size.width * 0.3, size.height * 0.85);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StopPainter extends CustomPainter {
  final Color color;
  _StopPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final r = size.width * 0.15;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.25,
          size.height * 0.25,
          size.width * 0.5,
          size.height * 0.5,
        ),
        Radius.circular(r),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CheckPainter extends CustomPainter {
  final Color color;
  _CheckPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(size.width * 0.2, size.height * 0.5);
    path.lineTo(size.width * 0.4, size.height * 0.7);
    path.lineTo(size.width * 0.8, size.height * 0.3);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HomePainter extends CustomPainter {
  final Color color;
  _HomePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(size.width * 0.1, size.height * 0.5);
    path.lineTo(size.width * 0.5, size.height * 0.12);
    path.lineTo(size.width * 0.9, size.height * 0.5);
    path.moveTo(size.width * 0.2, size.height * 0.45);
    path.lineTo(size.width * 0.2, size.height * 0.9);
    path.lineTo(size.width * 0.5, size.height * 0.9);
    path.lineTo(size.width * 0.5, size.height * 0.6);
    path.lineTo(size.width * 0.8, size.height * 0.6);
    path.lineTo(size.width * 0.8, size.height * 0.9);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TimelinePainter extends CustomPainter {
  final Color color;
  _TimelinePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, size.width * 0.15, paint);
    final linePaint = paint..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height * 0.3),
      linePaint,
    );
    canvas.drawLine(
      Offset(center.dx, size.height * 0.7),
      Offset(center.dx, size.height),
      linePaint,
    );
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width * 0.3, center.dy),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.7, center.dy),
      Offset(size.width, center.dy),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StatsPainter extends CustomPainter {
  final Color color;
  _StatsPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.15),
      Offset(size.width * 0.15, size.height * 0.85),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.85),
      Offset(size.width * 0.85, size.height * 0.85),
      paint,
    );
    final linePaint = paint..strokeWidth = 2;
    final path = Path();
    path.moveTo(size.width * 0.25, size.height * 0.65);
    path.lineTo(size.width * 0.4, size.height * 0.35);
    path.lineTo(size.width * 0.55, size.height * 0.5);
    path.lineTo(size.width * 0.75, size.height * 0.25);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProfilePainter extends CustomPainter {
  final Color color;
  _ProfilePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.35),
      size.width * 0.2,
      paint,
    );
    final path = Path();
    path.moveTo(size.width * 0.15, size.height * 0.9);
    path.quadraticBezierTo(
      size.width * 0.15,
      size.height * 0.6,
      size.width * 0.5,
      size.height * 0.6,
    );
    path.quadraticBezierTo(
      size.width * 0.85,
      size.height * 0.6,
      size.width * 0.85,
      size.height * 0.9,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SparklePainter extends CustomPainter {
  final Color color;
  _SparklePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(size.width * 0.5, 0);
    path.lineTo(size.width * 0.6, size.height * 0.35);
    path.lineTo(size.width, size.height * 0.4);
    path.lineTo(size.width * 0.65, size.height * 0.55);
    path.lineTo(size.width * 0.75, size.height);
    path.lineTo(size.width * 0.5, size.height * 0.65);
    path.lineTo(size.width * 0.25, size.height);
    path.lineTo(size.width * 0.35, size.height * 0.55);
    path.lineTo(0, size.height * 0.4);
    path.lineTo(size.width * 0.4, size.height * 0.35);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChevronRightPainter extends CustomPainter {
  final Color color;
  _ChevronRightPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(size.width * 0.35, size.height * 0.2);
    path.lineTo(size.width * 0.65, size.height * 0.5);
    path.lineTo(size.width * 0.35, size.height * 0.8);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChevronLeftPainter extends CustomPainter {
  final Color color;
  _ChevronLeftPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(size.width * 0.65, size.height * 0.2);
    path.lineTo(size.width * 0.35, size.height * 0.5);
    path.lineTo(size.width * 0.65, size.height * 0.8);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AddPainter extends CustomPainter {
  final Color color;
  _AddPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _iconStroke(color);
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.5),
      Offset(size.width * 0.8, size.height * 0.5),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.2),
      Offset(size.width * 0.5, size.height * 0.8),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EditPainter extends CustomPainter {
  final Color color;
  _EditPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _iconStroke(color);
    final pencil = Path()
      ..moveTo(size.width * 0.22, size.height * 0.7)
      ..lineTo(size.width * 0.28, size.height * 0.48)
      ..lineTo(size.width * 0.67, size.height * 0.09)
      ..quadraticBezierTo(
        size.width * 0.74,
        size.height * 0.02,
        size.width * 0.81,
        size.height * 0.09,
      )
      ..lineTo(size.width * 0.91, size.height * 0.19)
      ..quadraticBezierTo(
        size.width * 0.98,
        size.height * 0.26,
        size.width * 0.91,
        size.height * 0.33,
      )
      ..lineTo(size.width * 0.52, size.height * 0.72)
      ..lineTo(size.width * 0.3, size.height * 0.78)
      ..close();
    canvas.drawPath(pencil, paint);
    canvas.drawLine(
      Offset(size.width * 0.13, size.height * 0.9),
      Offset(size.width * 0.75, size.height * 0.9),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DeletePainter extends CustomPainter {
  final Color color;
  _DeletePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _iconStroke(color);
    canvas.drawLine(
      Offset(size.width * 0.18, size.height * 0.27),
      Offset(size.width * 0.82, size.height * 0.27),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.38, size.height * 0.14),
      Offset(size.width * 0.62, size.height * 0.14),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          size.width * 0.26,
          size.height * 0.35,
          size.width * 0.74,
          size.height * 0.88,
        ),
        Radius.circular(size.width * 0.06),
      ),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.42, size.height * 0.47),
      Offset(size.width * 0.42, size.height * 0.75),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.58, size.height * 0.47),
      Offset(size.width * 0.58, size.height * 0.75),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Paint _iconStroke(Color color) => Paint()
  ..color = color
  ..strokeWidth = 1.5
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;
