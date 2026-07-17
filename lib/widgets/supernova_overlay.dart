import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Weiße Supernova bei Zeitablauf: wächst aus der rechten oberen Ecke
/// (dort schlägt der Timer-Komet ein) mit weicher, nebelartiger Kante über
/// ~2 s zur vollständig weißen Fläche und blendet dann aus, um die nächste
/// Frage freizugeben.
///
/// Erwartet einen Controller mit Dauer ~1000 ms (`progress` 0..1):
/// 0.00–0.83 ausbreiten bis vollweiß · 0.83–0.90 halten · 0.90–1.0 auflösen.
/// Gemeinsam von Solo-Quiz und Endlos-Modus genutzt.
class SupernovaOverlay extends StatelessWidget {
  final Animation<double> progress;
  const SupernovaOverlay({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: progress,
          builder: (_, _) {
            final t = progress.value;
            if (t <= 0) return const SizedBox.shrink();
            return CustomPaint(painter: _SupernovaPainter(t));
          },
        ),
      ),
    );
  }
}

class _SupernovaPainter extends CustomPainter {
  final double t; // 0..1
  const _SupernovaPainter(this.t);

  static const _grow = 0.83; // bis hier aus der Ecke wachsen -> vollweiß
  static const _hold = 0.90; // vollweiß halten, dann auflösen

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Ursprung: rechts oben, wo der Komet das Timer-Ende erreicht.
    final origin = Offset(size.width, 0);
    final maxR = math.sqrt(size.width * size.width + size.height * size.height);

    if (t < _grow) {
      // Ausbreitende Supernova: weicher Kern, nebelartige transparente Kante.
      final edge = Curves.easeIn.transform(t / _grow);
      final radius = (edge * maxR * 1.15).clamp(1.0, maxR * 1.15);
      // früh viel Falloff (Nebel), später fast solider Kern -> vollweiß.
      final coreFrac = 0.35 + (0.98 - 0.35) * edge;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white,
            Colors.white,
            Colors.white.withValues(alpha: 0),
          ],
          stops: [0.0, coreFrac, 1.0],
        ).createShader(Rect.fromCircle(center: origin, radius: radius));
      canvas.drawRect(rect, paint);
    } else {
      // Vollweiß halten, dann ausblenden (gibt die neue Frage frei).
      final whiteout =
          t < _hold ? 1.0 : (1 - (t - _hold) / (1 - _hold)).clamp(0.0, 1.0);
      canvas.drawRect(
          rect, Paint()..color = Colors.white.withValues(alpha: whiteout));
    }
  }

  @override
  bool shouldRepaint(covariant _SupernovaPainter old) => old.t != t;
}
