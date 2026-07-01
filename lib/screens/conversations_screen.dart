import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../utils/icon_registry.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  /// Backward-compat: stare plany bez pola `icon` w kategorii rozmówek —
  /// mapowanie po `id` (które kiedyś było jedynym sposobem rozpoznania ikony).
  static const _legacyIconById = <String, IconData>{
    'rozm.powitania': Icons.waving_hand_outlined,
    'rozm.hotel': Icons.hotel_outlined,
    'rozm.restauracja': Icons.restaurant_menu,
    'rozm.sklep': Icons.shopping_basket_outlined,
    'rozm.stacja': Icons.local_gas_station_outlined,
    'rozm.droga': Icons.directions_outlined,
    'rozm.awaria': Icons.car_repair_outlined,
    'rozm.lekarz': Icons.medical_services_outlined,
    'rozm.sos': Icons.warning_amber_outlined,
  };

  /// Rozwiązuje ikonę kategorii rozmówki w kolejności:
  /// 1) z pola `icon` w JSON przez wspólny `kIconRegistry`,
  /// 2) fallback do mapowania po `id` (legacy),
  /// 3) domyślnie `chat_bubble_outline`.
  IconData _resolveIcon(Map k) {
    final iconName = k['icon'] as String?;
    if (iconName != null && kIconRegistry.containsKey(iconName)) {
      return kIconRegistry[iconName]!;
    }
    final id = k['id'] as String? ?? '';
    return _legacyIconById[id] ?? Icons.chat_bubble_outline;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripA = ref.watch(tripProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Rozmówki EN')),
      body: tripA.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Błąd: $e')),
        data: (trip) {
          final r = trip.practical['rozmowki'] as Map?;
          if (r == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Rozmówki nie są dostępne w tym planie. Zaimportuj zaktualizowany plan w Ustawieniach.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final kats = (r['kategorie'] as List? ?? []);
          return ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              if (r['info'] != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    r['info'] as String,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                  ),
                ),
              for (final k in kats) _kategoria(context, k as Map, scheme),
            ],
          );
        },
      ),
    );
  }

  Widget _kategoria(BuildContext c, Map k, ColorScheme scheme) {
    final name = k['name'] as String? ?? '';
    final phrases = (k['phrases'] as List? ?? []);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        leading: Icon(
          _resolveIcon(k),
          color: scheme.primary,
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${phrases.length} zwrotów',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          for (final p in phrases) _phraseRow(c, p as Map, scheme),
        ],
      ),
    );
  }

  Widget _phraseRow(BuildContext c, Map p, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p['en'] as String? ?? '',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: scheme.primary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            p['pl'] as String? ?? '',
            style: TextStyle(color: scheme.onSurface, fontSize: 14),
          ),
          if (p['pron'] != null) ...[
            const SizedBox(height: 2),
            Text(
              p['pron'] as String,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
