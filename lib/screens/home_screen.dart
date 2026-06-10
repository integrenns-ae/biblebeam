import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../data/question_repository.dart';
import '../l10n/strings.dart';
import '../models/question.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
import '../services/stats_service.dart';
import '../theme/app_theme.dart';
import '../widgets/starfield.dart';
import 'hotseat_setup_screen.dart';
import 'quiz_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repo = QuestionRepository();
  final Map<String, Future<QuestionPack>> _futures = {};
  int _difficulty = 0; // 0=alle, 1=leicht, 2=mittel, 3=schwer

  Future<QuestionPack> _futureFor(String lang) =>
      _futures[lang] ??= _repo.load(lang);

  void _startQuiz(QuestionPack pack, {String? category}) {
    SoundService.instance.play(Sfx.tap);
    var pool = category == null ? pack.questions : pack.byCategory(category);
    if (_difficulty > 0) {
      pool = pool.where((q) => q.difficulty == _difficulty).toList();
    }
    if (pool.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('noQuestions'))),
      );
      return;
    }
    final title = category == null
        ? tr('quickPlay')
        : trCategory(category,
            pack.categories.firstWhere((c) => c.slug == category).name);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuizScreen(pool: pool, title: title, categorySlug: category),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Starfield(
        child: SafeArea(
          child: ValueListenableBuilder<String>(
            valueListenable: SettingsService.instance.locale,
            builder: (context, lang, _) => FutureBuilder<QuestionPack>(
            future: _futureFor(lang),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: AppColors.gold));
              }
              final pack = snap.data!;
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _header(pack)),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 1.15,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final cat = pack.categories[i];
                          return _CategoryCard(
                            category: cat,
                            onTap: () => _startQuiz(pack, category: cat.slug),
                          )
                              .animate()
                              .fadeIn(delay: (60 * i).ms, duration: 350.ms)
                              .moveY(begin: 14, end: 0, curve: Curves.easeOut);
                        },
                        childCount: pack.categories.length,
                      ),
                    ),
                  ),
                ],
              );
            },
          )),
        ),
      ),
    );
  }

  Widget _twoPlayerButton(QuestionPack pack) {
    return GestureDetector(
      onTap: () {
        SoundService.instance.play(Sfx.tap);
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              HotseatSetupScreen(pack: pack, difficulty: _difficulty),
        ));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          color: AppColors.cardBg,
          border: Border.all(color: AppColors.player2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_alt_rounded, color: AppColors.player2, size: 20),
            const SizedBox(width: 8),
            Text(tr('twoPlayers'),
                style: AppTheme.ui(15, w: FontWeight.w600, c: AppColors.player2Bright)),
          ],
        ),
      ),
    );
  }

  Widget _difficultyChips() {
    final labels = [
      (0, tr('diffAll')),
      (1, tr('diffEasy')),
      (2, tr('diffMedium')),
      (3, tr('diffHard')),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('difficulty'),
            style: AppTheme.ui(13, w: FontWeight.w600, c: AppColors.creamDim)),
        const SizedBox(height: 8),
        Row(
          children: labels.map((e) {
            final selected = _difficulty == e.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  SoundService.instance.play(Sfx.tap);
                  setState(() => _difficulty = e.$1);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.gold : AppColors.cardBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: selected ? AppColors.gold : AppColors.cardBorder),
                  ),
                  child: Text(e.$2,
                      style: AppTheme.ui(13,
                          w: FontWeight.w600,
                          c: selected
                              ? AppColors.nightDeep
                              : AppColors.cream)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _header(QuestionPack pack) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.settings_rounded, color: AppColors.creamDim),
              tooltip: 'Settings',
              onPressed: () {
                SoundService.instance.play(Sfx.tap);
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const SettingsScreen()));
              },
            ),
          ),
          Icon(Icons.auto_awesome, color: AppColors.goldBright, size: 40)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 600.ms)
              .then()
              .shimmer(duration: 2400.ms, color: AppColors.cream),
          const SizedBox(height: 10),
          Text('Lichtpfad',
              style: GoogleFontsTitle.of(46),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(tr('tagline'),
              textAlign: TextAlign.center,
              style: AppTheme.ui(14, c: AppColors.creamDim)),
          const SizedBox(height: 22),
          _QuickPlayButton(onTap: () => _startQuiz(pack)),
          const SizedBox(height: 12),
          _twoPlayerButton(pack),
          const SizedBox(height: 20),
          _difficultyChips(),
          const SizedBox(height: 20),
          const _StatsStrip(),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(tr('regions'),
                style: AppTheme.ui(15, w: FontWeight.w600, c: AppColors.gold)),
          ),
        ],
      ),
    );
  }
}

/// kleiner Helfer für den Serifen-Titel
class GoogleFontsTitle {
  static TextStyle of(double size) =>
      AppTheme.dark().textTheme.displayLarge!.copyWith(
            fontSize: size,
            fontWeight: FontWeight.w600,
            color: AppColors.cream,
            letterSpacing: 1.5,
          );
}

class _QuickPlayButton extends StatelessWidget {
  final VoidCallback onTap;
  const _QuickPlayButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          gradient: const LinearGradient(
              colors: [AppColors.gold, AppColors.goldBright]),
          boxShadow: [
            BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.45),
                blurRadius: 24,
                spreadRadius: 1),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_arrow_rounded, color: AppColors.nightDeep),
            const SizedBox(width: 8),
            Text(tr('quickPlay'),
                style: AppTheme.ui(16,
                    w: FontWeight.w700, c: AppColors.nightDeep)),
          ],
        ),
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip();

  @override
  Widget build(BuildContext context) {
    final stats = StatsService.instance;
    Widget item(IconData icon, String value, String label) => Column(
          children: [
            Icon(icon, color: AppColors.gold, size: 20),
            const SizedBox(height: 4),
            Text(value, style: AppTheme.ui(16, w: FontWeight.w700)),
            Text(label, style: AppTheme.ui(11, c: AppColors.creamDim)),
          ],
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([
          stats.gamesPlayed,
          stats.bestScore,
          stats.totalCorrect,
          stats.totalQuestions,
        ]),
        builder: (_, _) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            item(Icons.casino_rounded, '${stats.gamesPlayed.value}', tr('games')),
            item(Icons.star_rounded, '${stats.bestScore.value}', tr('bestScore')),
            item(Icons.percent_rounded, '${stats.accuracyPct}%', tr('accuracy')),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final QuizCategory category;
  final VoidCallback onTap;
  const _CategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(category.slug);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: AppColors.cardBg,
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
                color: style.tint.withValues(alpha: 0.12),
                blurRadius: 18,
                spreadRadius: -2),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: style.tint.withValues(alpha: 0.16),
              ),
              child: Icon(style.icon, color: style.tint, size: 26),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trCategory(category.slug, category.name),
                    style: AppTheme.ui(16, w: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${category.count} ${tr('questions')}',
                    style: AppTheme.ui(12, c: AppColors.creamDim)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
