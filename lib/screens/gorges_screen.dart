import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/providers.dart';
import '../utils/icon_registry.dart';
import '../widgets/assistant_fab.dart';

/// Zakładka "Wąwozy" — lista wąwozów i wodospadów w okolicach zakwaterowania
/// w Alpach Julijskich. Dane czytane z `trip.practical.wawozy.miejsca[]`,
/// w pełni data-driven (nowe miejsca dodajesz w trip.json, bez ruszania kodu).
class GorgesScreen extends ConsumerWidget {
  const GorgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripA = ref.watch(tripProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Wąwozy')),
      floatingActionButton: const AssistantFab(),
      body: tripA.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Błąd: $e')),
        data: (trip) {
          final w = trip.practical['wawozy'] as Map?;
          if (w == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Wąwozy nie są dostępne w tym planie. Zaimportuj zaktualizowany plan w Ustawieniach.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final miejsca = (w['miejsca'] as List? ?? []);
          return ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              if (w['info'] != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    w['info'] as String,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                  ),
                ),
              for (final m in miejsca) _miejsce(context, m as Map, scheme),
            ],
          );
        },
      ),
    );
  }

  Widget _miejsce(BuildContext c, Map m, ColorScheme scheme) {
    final name = m['name'] as String? ?? '';
    final highlight = m['highlight'] as String?;
    final description = m['description'] as String?;
    final drive = m['driveFromKg'] as String?;
    final duration = m['duration'] as String?;
    final difficulty = m['difficulty'] as String?;
    final costEur = m['costEur'];
    final loc = m['location'] as Map?;
    final tips = (m['tips'] as List? ?? []).cast<dynamic>();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        leading: Icon(
          resolveIcon(m['icon'] as String?, fallback: Icons.landscape),
          color: scheme.primary,
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          _subtitle(drive, duration, difficulty),
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          if (highlight != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.star, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      highlight,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (description != null) ...[
            const SizedBox(height: 10),
            Text(description, style: const TextStyle(fontSize: 14)),
          ],
          const SizedBox(height: 10),
          _facts(c, drive, duration, difficulty, costEur, scheme),
          if (tips.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...tips.map((t) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('• '),
                    Expanded(child: Text(t.toString(), style: const TextStyle(fontSize: 13))),
                  ]),
                )),
          ],
          if (loc != null) ...[
            const SizedBox(height: 10),
            _mapButton(c, loc, scheme),
          ],
        ],
      ),
    );
  }

  /// Podsumowanie pod tytułem: "30 min z KG · 1h · Łatwa"
  String _subtitle(String? drive, String? duration, String? difficulty) {
    final parts = <String>[];
    if (drive != null) parts.add('${_formatDuration(drive)} z KG');
    if (duration != null) parts.add(_formatDuration(duration));
    if (difficulty != null) parts.add(difficulty);
    return parts.join(' · ');
  }

  /// Tabelka faktów (czas dojazdu, czas zwiedzania, trudność, koszt).
  Widget _facts(BuildContext c, String? drive, String? duration, String? difficulty,
      dynamic costEur, ColorScheme scheme) {
    Widget row(IconData ic, String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Icon(ic, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 13))),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (drive != null) row(Icons.directions_car, 'Dojazd z KG', _formatDuration(drive)),
        if (duration != null) row(Icons.schedule, 'Czas zwiedzania', _formatDuration(duration)),
        if (difficulty != null) row(Icons.terrain, 'Trudność', difficulty),
        if (costEur != null)
          row(Icons.payments_outlined, 'Koszt orientacyjnie', '~$costEur €'),
      ],
    );
  }

  Widget _mapButton(BuildContext c, Map loc, ColorScheme scheme) {
    final lat = loc['lat'];
    final lng = loc['lng'];
    final name = loc['name'] as String? ?? '';
    if (lat is! num || lng is! num) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.tonalIcon(
        icon: const Icon(Icons.map_outlined, size: 18),
        label: Text('Otwórz w mapach: $name'),
        onPressed: () {
          final uri = Uri.parse('geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(name)})');
          launchUrl(uri, mode: LaunchMode.externalApplication);
        },
      ),
    );
  }

  /// Konwertuje ISO 8601 duration (PT1H30M, PT45M, PT2H) na czytelny tekst polski.
  String _formatDuration(String iso) {
    final match = RegExp(r'^PT(?:(\d+)H)?(?:(\d+)M)?').firstMatch(iso);
    if (match == null) return iso;
    final h = int.tryParse(match.group(1) ?? '0') ?? 0;
    final m = int.tryParse(match.group(2) ?? '0') ?? 0;
    if (h > 0 && m > 0) return '${h}h ${m}min';
    if (h > 0) return '${h}h';
    if (m > 0) return '${m}min';
    return iso;
  }
}
