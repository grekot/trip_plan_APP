import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app_router.dart';
import 'providers/providers.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pl_PL', null);
  await Hive.initFlutter();
  await Future.wait([
    Hive.openBox(boxProgress),
    Hive.openBox(boxNotes),
    Hive.openBox(boxPacking),
    Hive.openBox(boxSettings),
  ]);
  runApp(const ProviderScope(child: SloweniaApp()));
}

class SloweniaApp extends ConsumerWidget {
  const SloweniaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripA = ref.watch(tripProvider);
    final trip = tripA.valueOrNull;

    // Tytuł i kolor wiodący są ładowane z trip.json. Jeśli plan jeszcze
    // się nie załadował lub nie podaje swoich wartości — używamy fallbacków.
    final title = trip?.title ?? 'Plan Podróży';
    final themeMap = trip?.practical['theme'] as Map?;
    final seedColor = _parseHexColor(themeMap?['primaryColor'] as String?) ?? AppTheme.defaultSeed;

    return MaterialApp.router(
      title: title,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(seedColor: seedColor),
      darkTheme: AppTheme.dark(seedColor: seedColor),
      themeMode: ThemeMode.system,
      locale: const Locale('pl', 'PL'),
      supportedLocales: const [Locale('pl', 'PL'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: appRouter,
    );
  }
}

/// Parsuje kolor hex (`#RRGGBB` lub `RRGGBB`) na obiekt `Color`.
/// Zwraca `null` przy błędnym wejściu — caller decyduje o fallbacku.
Color? _parseHexColor(String? hex) {
  if (hex == null) return null;
  final clean = hex.replaceFirst('#', '').trim();
  if (clean.length != 6) return null;
  final value = int.tryParse(clean, radix: 16);
  if (value == null) return null;
  return Color(value | 0xFF000000);
}
