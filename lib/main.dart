import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/library.dart';
import 'core/scopes.dart';
import 'core/settings.dart';
import 'core/themes.dart';
import 'desktop/desktop_shell.dart';
import 'screens/home_screen.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Release builds draw a blank grey box for a widget that throws; show the error instead.
  ErrorWidget.builder = (details) => Material(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(details.exceptionAsString(),
              style: const TextStyle(color: Colors.red, fontSize: 12)),
        ),
      );
  // Windows passes the file that was double-clicked or opened with RelaxMD.
  final file = args.where(isMarkdownPath).firstOrNull;
  await start(initialFile: file);
}

/// Loads the saved settings and runs the app. Anything that goes wrong here
/// would otherwise leave the phone on the launch screen forever, because no
/// frame is ever drawn - so the error is shown on screen instead.
Future<void> start({String? initialFile}) async {
  try {
    final prefs = await SharedPreferences.getInstance()
        .timeout(const Duration(seconds: 10));
    runApp(RelaxMdApp(
        settings: AppSettings(prefs),
        library: DocLibrary(prefs),
        initialFile: initialFile));
  } catch (error, stack) {
    debugPrint('RelaxMD failed to start: $error\n$stack');
    runApp(StartupErrorApp(
        error: error,
        stack: stack,
        onRetry: () => start(initialFile: initialFile)));
  }
}

/// Shown instead of the app when startup fails, with the error so it can be reported.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp(
      {super.key, required this.error, required this.stack, required this.onRetry});

  final Object error;
  final StackTrace stack;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RelaxMD',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('تعذر تشغيل RelaxMD',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Text("RelaxMD couldn't start",
                  style: TextStyle(fontSize: 18)),
              const SizedBox(height: 16),
              SelectableText('$error\n\n$stack',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => unawaited(onRetry()),
                child: const Text('إعادة المحاولة / Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RelaxMdApp extends StatelessWidget {
  const RelaxMdApp(
      {super.key, required this.settings, required this.library, this.initialFile});

  final AppSettings settings;
  final DocLibrary library;

  /// Opened right away, when the app was started with a file.
  final String? initialFile;

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
            navigatorKey: appNavigator,
            builder: isDesktop
                ? (context, child) => DesktopDropZone(child: child!)
                : null,
            home: HomeScreen(initialFile: initialFile),
          );
        }),
      ),
    );
  }
}
