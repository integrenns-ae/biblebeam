import 'dart:math';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Ruhiger Nachthimmel-Hintergrund mit sanftem Goldschein oben –
/// Basis der "Lichtpfad"-Optik. Sterne deterministisch (fester Seed).
class Starfield extends StatelessWidget {
  final Widget child;
  const Starfield({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.7),
          radius: 1.4,
          colors: [AppColors.indigo, AppColors.night, AppColors.nightDeep],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: _StarPainter(),
        child: child,
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(20260606);
    final paint = Paint();
    for (int i = 0; i < 90; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 1.3 + 0.3;
      final op = rng.nextDouble() * 0.5 + 0.15;
      paint.color = AppColors.cream.withValues(alpha: op);
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
    // ein paar goldene "Lichter"
    for (int i = 0; i < 8; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height * 0.6;
      paint.color = AppColors.gold.withValues(alpha: 0.18);
      canvas.drawCircle(Offset(dx, dy), rng.nextDouble() * 1.6 + 0.8, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
