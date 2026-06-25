import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_theme.dart';

/// Animierter Weltraum-Hintergrund der "Lichtpfad"-Optik:
///  - dunkles Basis-Gradient
///  - langsam driftende Nebel-Glows (das "animierte Space-Gradient")
///  - weiße, kühl schimmernde Sterne, die flimmern
///
/// Performance: Der ganze Hintergrund liegt in einer eigenen RepaintBoundary
/// und wird über einen Ticker betrieben, der auf ~30 fps gedrosselt ist. So
/// repaintet das Vordergrund-UI (Quiz, Timer, Effekte) NICHT mit – wichtig auf
/// Mobilgeräten (frühere Lag-Quelle). Sterne deterministisch (fester Seed).
class Starfield extends StatelessWidget {
  final Widget child;
  const Starfield({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const RepaintBoundary(child: _AnimatedBackground()),
        child,
      ],
    );
  }
}

class _Star {
  final double x, y, r, baseAlpha, twAmp, twSpeed, phase;
  final Color color;
  const _Star(this.x, this.y, this.r, this.baseAlpha, this.twAmp, this.twSpeed,
      this.phase, this.color);
}

class _AnimatedBackground extends StatefulWidget {
  const _AnimatedBackground();

  @override
  State<_AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<_AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _t = ValueNotifier(0);
  double _lastEmit = -1;
  late final List<_Star> _stars;

  // Weißtöne (eher weiß/kühl als gelb), mit etwas Temperatur-Variation.
  static const _whites = <Color>[
    Color(0xFFFFFFFF),
    Color(0xFFEAF1FF), // leicht kühl
    Color(0xFFFDF7FF), // leicht violett-weiß
    Color(0xFFCBDDFF), // bläulich
  ];

  @override
  void initState() {
    super.initState();
    final rng = Random(20260606);
    _stars = List.generate(120, (_) {
      final size = rng.nextDouble();
      return _Star(
        rng.nextDouble(), // x (0..1)
        rng.nextDouble(), // y (0..1)
        size * 1.4 + 0.3, // Radius
        rng.nextDouble() * 0.38 + 0.18, // Grund-Helligkeit
        rng.nextDouble() * 0.34 + 0.14, // Flimmer-Amplitude
        rng.nextDouble() * 2.6 + 1.4, // Flimmer-Tempo (rad/s)
        rng.nextDouble() * pi * 2, // Phase
        _whites[rng.nextInt(_whites.length)],
      );
    });
    _ticker = createTicker((elapsed) {
      final s = elapsed.inMicroseconds / 1e6;
      // auf ~30 fps drosseln -> halbe Repaint-Last
      if (s - _lastEmit >= 0.033) {
        _lastEmit = s;
        _t.value = s;
      }
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SpacePainter(_stars, _t),
      size: Size.infinite,
    );
  }
}

class _SpacePainter extends CustomPainter {
  final List<_Star> stars;
  final ValueNotifier<double> t;
  _SpacePainter(this.stars, this.t) : super(repaint: t);

  // Basis-Gradient cachen (ändert sich nur bei Größenwechsel).
  Shader? _baseShader;
  Size? _baseSize;

  @override
  void paint(Canvas canvas, Size size) {
    final time = t.value;
    final rect = Offset.zero & size;

    // 1) Dunkles Basis-Weltraum-Gradient
    if (_baseShader == null || _baseSize != size) {
      _baseSize = size;
      _baseShader = const RadialGradient(
        center: Alignment(0, -0.7),
        radius: 1.4,
        colors: [AppColors.indigo, AppColors.night, AppColors.nightDeep],
        stops: [0.0, 0.55, 1.0],
      ).createShader(rect);
    }
    canvas.drawRect(rect, Paint()..shader = _baseShader);

    // 2) Driftende, atmende Nebel-Glows -> deutlich sichtbares animiertes
    //    Space-Gradient (kräftige Farben, große Bewegung, ~15-25 s Perioden).
    final big = max(size.width, size.height);
    void nebula(double nx, double ny, double radF, Color c, double a) {
      final center = Offset(nx * size.width, ny * size.height);
      final radius = big * radF;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [c.withValues(alpha: a), c.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    // baseA + „Atmen" der Helligkeit, damit die Bewegung klar auffällt.
    double breathe(double base, double amp, double speed, double ph) =>
        (base + amp * sin(time * speed + ph)).clamp(0.0, 1.0);

    nebula(
        0.30 + 0.16 * sin(time * 0.34),
        0.22 + 0.13 * cos(time * 0.30),
        0.62,
        const Color(0xFF6A4DEB), // helles Indigo-Violett
        breathe(0.52, 0.16, 0.5, 0.0));
    nebula(
        0.74 + 0.17 * sin(time * 0.27 + 1.5),
        0.64 + 0.15 * cos(time * 0.31 + 2.0),
        0.56,
        const Color(0xFF2E7BE0), // kräftiges Blau
        breathe(0.48, 0.16, 0.45, 2.0));
    nebula(
        0.52 + 0.15 * sin(time * 0.40 + 3.0),
        0.90 + 0.12 * cos(time * 0.36 + 1.0),
        0.50,
        const Color(0xFFA84CE0), // Magenta-Violett
        breathe(0.42, 0.16, 0.55, 1.0));

    // 3) Flimmernde weiße Sterne
    final sp = Paint();
    for (final s in stars) {
      final a = (s.baseAlpha + s.twAmp * sin(time * s.twSpeed + s.phase))
          .clamp(0.0, 1.0);
      sp.color = s.color.withValues(alpha: a);
      canvas.drawCircle(Offset(s.x * size.width, s.y * size.height), s.r, sp);
    }
  }

  // Neuzeichnen erfolgt über den Listenable [t]; kein Vergleich nötig.
  @override
  bool shouldRepaint(covariant _SpacePainter oldDelegate) => false;
}
