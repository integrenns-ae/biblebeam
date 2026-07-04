import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../l10n/strings.dart';
import '../services/stats_service.dart';
import '../theme/app_theme.dart';
import '../widgets/starfield.dart';

/// „Sternbild der Weisheit" (Daniel 12,3): ein persönlicher, wachsender
/// Sternenhimmel – ein flimmernder Stern je jemals richtig beantworteter Frage.
class WisdomSkyScreen extends StatefulWidget {
  const WisdomSkyScreen({super.key});

  @override
  State<WisdomSkyScreen> createState() => _WisdomSkyScreenState();
}

class _Star {
  final double x, y, r, baseA, amp, speed, phase;
  const _Star(this.x, this.y, this.r, this.baseA, this.amp, this.speed, this.phase);
}

// Schwelle -> String-Key des Rang-/Sternbild-Namens.
const _tiers = <List<Object>>[
  [0, 'skyRank0'],
  [1, 'skyRank1'],
  [25, 'skyRank2'],
  [100, 'skyRank3'],
  [300, 'skyRank4'],
  [700, 'skyRank5'],
  [1500, 'skyRank6'],
];

class _WisdomSkyScreenState extends State<WisdomSkyScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _t = ValueNotifier(0);
  double _last = -1;
  late final List<_Star> _stars;
  late final int _count;

  @override
  void initState() {
    super.initState();
    _count = StatsService.instance.totalCorrect.value;
    final n = _count.clamp(0, 500); // gerenderte Sterne begrenzen (Perf)
    final rng = Random(0x5721);
    _stars = List.generate(
      n,
      (_) => _Star(
        rng.nextDouble(),
        0.06 + rng.nextDouble() * 0.9, // y – etwas Abstand oben/unten
        rng.nextDouble() * 1.6 + 1.0, // Radius
        rng.nextDouble() * 0.4 + 0.35, // Grundhelligkeit
        rng.nextDouble() * 0.35 + 0.15, // Flimmer-Amplitude
        rng.nextDouble() * 2.2 + 0.8, // Tempo
        rng.nextDouble() * pi * 2, // Phase
      ),
    );
    _ticker = createTicker((el) {
      final s = el.inMicroseconds / 1e6;
      if (s - _last >= 0.033) {
        _last = s;
        _t.value = s;
      } // ~30 fps
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  ({String name, int curAt, int? nextAt, String? nextName}) _rank() {
    var idx = 0;
    for (var i = 0; i < _tiers.length; i++) {
      if (_count >= (_tiers[i][0] as int)) idx = i;
    }
    final name = tr(_tiers[idx][1] as String);
    final curAt = _tiers[idx][0] as int;
    if (idx + 1 < _tiers.length) {
      return (
        name: name,
        curAt: curAt,
        nextAt: _tiers[idx + 1][0] as int,
        nextName: tr(_tiers[idx + 1][1] as String)
      );
    }
    return (name: name, curAt: curAt, nextAt: null, nextName: null);
  }

  @override
  Widget build(BuildContext context) {
    final rank = _rank();
    return Scaffold(
      body: Starfield(
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(painter: _SkyPainter(_stars, _t)),
                ),
              ),
              // Lesbarkeits-Schleier oben & unten
              _scrim(top: true),
              _scrim(top: false),
              Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: AppColors.creamDim),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        Text(tr('skyTitle'),
                            textAlign: TextAlign.center,
                            style: AppTheme.ui(15,
                                w: FontWeight.w700, c: AppColors.gold)),
                        const SizedBox(height: 14),
                        Text('„${tr('skyVerse')}"',
                            textAlign: TextAlign.center,
                            style: AppTheme.dark()
                                .textTheme
                                .titleMedium!
                                .copyWith(
                                    color: AppColors.cream,
                                    fontStyle: FontStyle.italic,
                                    height: 1.45)),
                        const SizedBox(height: 8),
                        Text('— ${tr('skyRef')}',
                            style: AppTheme.ui(12, c: AppColors.creamDim)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _footer(rank),
                  const SizedBox(height: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scrim({required bool top}) {
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: 0,
      right: 0,
      height: top ? 300 : 200,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: top ? Alignment.topCenter : Alignment.bottomCenter,
              end: top ? Alignment.bottomCenter : Alignment.topCenter,
              colors: [
                AppColors.nightDeep.withValues(alpha: 0.85),
                AppColors.nightDeep.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer(({String name, int curAt, int? nextAt, String? nextName}) rank) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text('$_count',
              style: AppTheme.dark().textTheme.displayMedium!.copyWith(
                    color: AppColors.cream,
                    fontWeight: FontWeight.w800,
                    shadows: const [
                      Shadow(color: AppColors.gold, blurRadius: 22)
                    ],
                  )),
          Text(tr('skyStarsLabel'),
              style: AppTheme.ui(13, c: AppColors.creamDim)),
          const SizedBox(height: 12),
          Text(rank.name,
              style: AppTheme.ui(17, w: FontWeight.w700, c: AppColors.goldBright)),
          if (_count == 0) ...[
            const SizedBox(height: 8),
            Text(tr('skyEmpty'),
                textAlign: TextAlign.center,
                style: AppTheme.ui(13, c: AppColors.creamDim)),
          ] else if (rank.nextAt != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ((_count - rank.curAt) / (rank.nextAt! - rank.curAt))
                    .clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppColors.cardBorder,
                valueColor: const AlwaysStoppedAnimation(AppColors.gold),
              ),
            ),
            const SizedBox(height: 6),
            Text('${rank.nextAt! - _count} ${tr('skyNext')} · ${rank.nextName}',
                textAlign: TextAlign.center,
                style: AppTheme.ui(12, c: AppColors.creamDim)),
          ],
        ],
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  final List<_Star> stars;
  final ValueNotifier<double> t;
  _SkyPainter(this.stars, this.t) : super(repaint: t);

  static final _warm = Color.lerp(AppColors.cream, AppColors.goldBright, 0.3)!;

  @override
  void paint(Canvas canvas, Size size) {
    final time = t.value;
    final glow = Paint();
    final core = Paint();
    for (final s in stars) {
      final a = (s.baseA + s.amp * sin(time * s.speed + s.phase)).clamp(0.0, 1.0);
      final o = Offset(s.x * size.width, s.y * size.height);
      glow.color = AppColors.goldBright.withValues(alpha: a * 0.16);
      canvas.drawCircle(o, s.r * 2.4, glow); // weiches Glühen (ohne Blur, günstig)
      core.color = _warm.withValues(alpha: a);
      canvas.drawCircle(o, s.r, core);
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter oldDelegate) => false;
}
