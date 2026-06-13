import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/achievement_service.dart';
import '../theme/app_theme.dart';
import '../widgets/starfield.dart';

/// Übersicht der 30 Achievements in fünf parallelen Blöcken.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  static const _blockKeys = {
    1: 'block1',
    2: 'block2',
    3: 'block3',
    4: 'block4',
    5: 'block5',
  };

  @override
  Widget build(BuildContext context) {
    final svc = AchievementService.instance;
    return Scaffold(
      body: Starfield(
        child: SafeArea(
          child: ValueListenableBuilder<int>(
            valueListenable: svc.revision,
            builder: (context, _, _) {
              final blocks = <int, List<Achievement>>{};
              for (final a in svc.catalog) {
                (blocks[a.block] ??= []).add(a);
              }
              for (final list in blocks.values) {
                list.sort((x, y) => x.threshold.compareTo(y.threshold));
              }
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _header(context, svc)),
                  for (final b in [1, 2, 3, 4, 5])
                    if (blocks[b] != null) ...[
                      SliverToBoxAdapter(child: _blockHeader(b)),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _AchievementCard(
                            achievement: blocks[b]![i],
                            svc: svc,
                          ),
                          childCount: blocks[b]!.length,
                        ),
                      ),
                    ],
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, AchievementService svc) {
    final total = svc.catalog.length;
    final done = svc.unlockedCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.creamDim),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(tr('achievements'),
                    textAlign: TextAlign.center,
                    style: AppTheme.ui(18, w: FontWeight.w700, c: AppColors.gold)),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 6),
          Text('$done / $total',
              style: AppTheme.dark()
                  .textTheme
                  .displaySmall!
                  .copyWith(color: AppColors.cream, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 6,
              backgroundColor: AppColors.cardBorder,
              valueColor: const AlwaysStoppedAnimation(AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blockHeader(int block) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Text(tr(_blockKeys[block]!),
          style: AppTheme.ui(15, w: FontWeight.w700, c: AppColors.player2Bright)),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final AchievementService svc;
  const _AchievementCard({required this.achievement, required this.svc});

  static const _months = [
    'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
    'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'
  ];

  String _fmtDate(DateTime d) =>
      '${d.day}. ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final state = svc.stateOf(a);
    final unlocked = state == AchState.unlocked;
    final hiddenLocked = a.hidden && !unlocked;

    final title = hiddenLocked ? '???' : a.titleText;
    final accent = unlocked ? AppColors.gold : AppColors.creamDim;

    IconData icon;
    if (unlocked) {
      icon = Icons.emoji_events_rounded;
    } else if (a.hidden) {
      icon = Icons.help_outline_rounded;
    } else {
      icon = Icons.lock_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: unlocked ? 0.9 : 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked ? AppColors.gold.withValues(alpha: 0.6) : AppColors.cardBorder,
          width: 1.2,
        ),
        boxShadow: unlocked
            ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.18), blurRadius: 14)]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.15),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTheme.ui(16,
                        w: FontWeight.w700,
                        c: unlocked ? AppColors.cream : AppColors.creamDim)),
                const SizedBox(height: 2),
                if (!hiddenLocked) ...[
                  Text(a.conditionText,
                      style: AppTheme.ui(12, c: AppColors.creamDim)),
                  if (unlocked) ...[
                    const SizedBox(height: 4),
                    Text('“${a.tooltipText}”',
                        style: AppTheme.ui(11.5,
                            c: AppColors.gold, w: FontWeight.w500)),
                    if (svc.unlockedAt(a.id) != null) ...[
                      const SizedBox(height: 4),
                      Text('${tr('achUnlockedOn')} ${_fmtDate(svc.unlockedAt(a.id)!)}',
                          style: AppTheme.ui(11, c: AppColors.creamDim)),
                    ],
                  ] else if (a.measurable) ...[
                    const SizedBox(height: 8),
                    _progressBar(a),
                  ],
                ] else
                  Text(tr('achHiddenHint'),
                      style: AppTheme.ui(12, c: AppColors.creamDim)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressBar(Achievement a) {
    final cur = a.progress(svc).clamp(0, a.threshold);
    final frac = a.threshold == 0 ? 0.0 : cur / a.threshold;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: frac.toDouble().clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: AppColors.cardBorder,
            valueColor: const AlwaysStoppedAnimation(AppColors.player2),
          ),
        ),
        const SizedBox(height: 3),
        Text('${cur.toInt()} / ${a.threshold}',
            style: AppTheme.ui(11, c: AppColors.creamDim)),
      ],
    );
  }
}
