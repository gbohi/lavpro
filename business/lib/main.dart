import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lavpro_core/lavpro_core.dart';

import 'router.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  runApp(const ProviderScope(child: LavproBusinessApp()));
}

class LavproBusinessApp extends ConsumerWidget {
  const LavproBusinessApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'Lavpro Business',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ref.watch(themeModeProvider),
        routerConfig: ref.watch(routerProvider),
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      );
}
