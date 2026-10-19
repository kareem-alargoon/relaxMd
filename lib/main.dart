import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/library.dart';
import 'core/scopes.dart';
import 'core/settings.dart';
import 'core/themes.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(RelaxMdApp(settings: AppSettings(prefs), library: DocLibrary(prefs)));
}

class RelaxMdApp extends StatelessWidget {
  const RelaxMdApp({super.key, required this.settings, required this.library});

  final AppSettings settings;
  final DocLibrary library;

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      notifier: settings,
      child: LibraryScope(
        notifier: library,
        child: Builder(builder: (context) {
          final s = SettingsScope.of(context);
          final followSystem = s.theme == 'system';
          final light = buildTheme(palettes[followSystem ? 'paper' : s.theme]!);
          final dark = followSystem ? buildTheme(palettes['dim']!) : light;
          return MaterialApp(
            title: 'RelaxMD',
            debugShowCheckedModeBanner: false,
            theme: light,
            darkTheme: dark,
            themeMode: followSystem ? ThemeMode.system : ThemeMode.light,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            supportedLocales: const [Locale('en'), Locale('ar')],
            home: const HomeScreen(),
          );
        }),
      ),
    );
  }
}
