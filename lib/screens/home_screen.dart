import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../data/trip_loader.dart';
import '../providers/providers.dart';
import '../widgets/assistant_fab.dart';
import '../widgets/progress_bar.dart';
import 'day_detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripA = ref.watch(tripProvider);
    final settings = ref.watch(settingsProvider);
    final activeIdx = ref.watch(activeDayIndexProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: tripA.when(
          data: (t) => Text(t.title),
          loading: () => const Text('Ładowanie…'),
          error: (_, __) => const Text('Błąd'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      drawer: const _AppDrawer(),
      floatingActionButton: const AssistantFab(),
      body: tripA.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => e is NoActivePlanException
            ? _noPlanPanel(context)
            : Center(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Błąd wczytywania planu:\n$e', textAlign: TextAlign.center),
              )),
        data: (trip) {
          if (settings.tripStartDate == null) {
            return _onboardingPanel(context, ref);
          }
          if (activeIdx == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (activeIdx < 0) {
            final daysLeft = settings.tripStartDate!
                .difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))
                .inDays;
            return _beforeTripPanel(context, daysLeft, settings.tripStartDate!);
          }
          if (activeIdx >= trip.days.length) {
            return _afterTripPanel(context);
          }
          final day = trip.days[activeIdx];
          final progress = ref.watch(dayProgressProvider(day.id));
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dzisiaj — Dzień ${day.number} z ${trip.days.length}',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(day.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(day.summary, style: TextStyle(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: DayProgressBar(value: progress)),
                      const SizedBox(width: 8),
                      Text('${(progress * 100).round()}%',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                  ],
                ),
              ),
              ...day.sections.map((s) => DaySectionView(section: s, dayId: day.id)).toList(),
              if (day.alternatives.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.alt_route),
                    label: Text('Pokaż ${day.alternatives.length} alternatyw'),
                    onPressed: () => context.push('/day/${day.id}'),
                  ),
                ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _noPlanPanel(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.travel_explore, size: 64),
          const SizedBox(height: 16),
          const Text('Brak aktywnego planu',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Aby zacząć: ustaw hasło i pobierz plan podróży z chmury.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.cloud_download_outlined),
            label: const Text('Otwórz Bibliotekę planów'),
            onPressed: () => context.push('/library'),
          ),
        ],
      ),
    );
  }

  Widget _onboardingPanel(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_outlined, size: 64),
          const SizedBox(height: 16),
          const Text('Witaj!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Ustaw datę startu wyjazdu, aby aplikacja mogła pokazywać aktywny dzień planu.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.calendar_month),
            label: const Text('Ustaw datę startu'),
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 2),
                initialDate: now,
              );
              if (picked != null) {
                await ref.read(settingsProvider.notifier).setTripStartDate(picked);
              }
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.checklist),
            label: const Text('Pokaż checklist pakowania'),
            onPressed: () => context.push('/packing'),
          ),
        ],
      ),
    );
  }

  Widget _beforeTripPanel(BuildContext context, int daysLeft, DateTime startDate) {
    final df = DateFormat('EEEE, d MMMM yyyy', 'pl_PL');
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.luggage_outlined, size: 64),
          const SizedBox(height: 12),
          Text('Do wyjazdu: $daysLeft ${_daysWord(daysLeft)}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Start: ${df.format(startDate)}', textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.checklist),
            label: const Text('Sprawdź pakowanie'),
            onPressed: () => context.push('/packing'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.view_day_outlined),
            label: const Text('Przeglądaj dni'),
            onPressed: () => context.push('/days'),
          ),
        ],
      ),
    );
  }

  Widget _afterTripPanel(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.celebration_outlined, size: 64),
          const SizedBox(height: 12),
          const Text('Wyjazd zakończony 🎉',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Możesz przeglądać dni i notatki w archiwum.',
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.view_day_outlined),
            label: const Text('Archiwum dni'),
            onPressed: () => context.push('/days'),
          ),
        ],
      ),
    );
  }

  String _daysWord(int n) {
    if (n == 1) return 'dzień';
    final m = n % 10;
    final t = n % 100;
    if (m >= 2 && m <= 4 && (t < 10 || t >= 20)) return 'dni';
    return 'dni';
  }
}

class _AppDrawer extends ConsumerWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tripA = ref.watch(tripProvider);
    final trip = tripA.valueOrNull;

    // Tytuł apki w nagłówku drawera — z trip.json (fallback: 'Plan wycieczki').
    final headerTitle = trip?.title ?? 'Plan Podróży';

    // Mapa etykiet menu — może być nadpisana w `trip.practical.menu` (klucz =
    // route bez `/`, wartość = etykieta). Domyślnie polskie nazwy.
    final menuOverrides = trip?.practical['menu'] as Map?;
    String label(String key, String fallback) =>
        (menuOverrides?[key] as String?) ?? fallback;

    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 16, 8),
              child: Text(headerTitle,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: scheme.primary)),
            ),
            const Divider(),
            _entry(context, Icons.today_outlined, label('today', 'Dzisiaj'), '/'),
            _entry(context, Icons.view_day_outlined, label('days', 'Wszystkie dni'), '/days'),
            _entry(context, Icons.explore_outlined, label('extras', 'Atrakcje dodatkowe'), '/extras'),
            _entry(context, Icons.checklist, label('packing', 'Pakowanie'), '/packing'),
            _entry(context, Icons.menu_book_outlined, label('practical', 'Praktyczne'), '/practical'),
            _entry(context, Icons.record_voice_over_outlined, label('conversations', 'Rozmówki EN'), '/conversations'),
            _entry(context, Icons.water_outlined, label('gorges', 'Wąwozy'), '/gorges'),
            _entry(context, Icons.phone_in_talk_outlined, label('emergency', 'Awaryjne'), '/emergency'),
            _entry(context, Icons.auto_stories_outlined, label('journal', 'Dziennik podróży'), '/journal'),
            const Divider(),
            _entry(context, Icons.smart_toy_outlined, label('assistant', 'Asystent AI'), '/assistant'),
            _entry(context, Icons.library_books_outlined, label('library', 'Biblioteka planów'), '/library'),
            _entry(context, Icons.settings_outlined, label('settings', 'Ustawienia'), '/settings'),
          ],
        ),
      ),
    );
  }

  Widget _entry(BuildContext c, IconData ic, String label, String path) =>
      ListTile(
        leading: Icon(ic),
        title: Text(label),
        onTap: () {
          Navigator.pop(c);
          if (path == '/') {
            c.go(path);
          } else {
            c.push(path);
          }
        },
      );
}
