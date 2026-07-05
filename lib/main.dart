import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/home_screen.dart';
import 'services/achievement_service.dart';
import 'services/settings_service.dart';
import 'services/stats_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.instance.init();
  await StatsService.instance.init();
  await AchievementService.instance.init();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  runApp(const BibelquizApp());
}

class BibelquizApp extends StatelessWidget {
  const BibelquizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: SettingsService.instance.locale,
      builder: (context, lang, _) => MaterialApp(
        title: 'Queezra – Bible Quiz',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        locale: Locale(lang),
        supportedLocales: const [Locale('en'), Locale('de'), Locale('ru')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const HomeScreen(),
      ),
    );
  }
}
