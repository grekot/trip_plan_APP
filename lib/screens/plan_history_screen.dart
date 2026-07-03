import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/providers.dart';
import '../services/plan_history_service.dart';

/// Historia zmian planu — lista snapshotów (przed akcjami agenta AI,
/// importem, przywróceniem) z możliwością cofnięcia planu do danego stanu.
class PlanHistoryScreen extends ConsumerStatefulWidget {
  const PlanHistoryScreen({super.key});

  @override
  ConsumerState<PlanHistoryScreen> createState() => _PlanHistoryScreenState();
}

class _PlanHistoryScreenState extends ConsumerState<PlanHistoryScreen> {
  List<PlanSnapshot>? _snapshots;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await PlanHistoryService.list();
    if (mounted) setState(() => _snapshots = list);
  }

  Future<void> _restore(PlanSnapshot s) async {
    final df = DateFormat('d MMM yyyy, HH:mm', 'pl_PL');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Przywrócić ten stan planu?'),
        content: Text(
            'Snapshot z ${df.format(s.savedAt)}\n„${s.label}”\n\n'
            'Bieżący stan planu zostanie zapisany w historii, więc tę operację '
            'też da się cofnąć. Notatki i odznaczenia nie są zmieniane.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Anuluj')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Przywróć')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final restored = await PlanHistoryService.readTrip(s);
      final current = ref.read(tripProvider).valueOrNull;
      if (current != null) {
        await PlanHistoryService.snapshot(current, 'Przed przywróceniem');
      }
      await ref.read(tripProvider.notifier).replace(restored);
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Plan przywrócony')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Błąd przywracania: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final df = DateFormat('EEEE, d MMM yyyy, HH:mm', 'pl_PL');
    final snapshots = _snapshots;

    return Scaffold(
      appBar: AppBar(title: const Text('Historia zmian planu')),
      body: snapshots == null
          ? const Center(child: CircularProgressIndicator())
          : snapshots.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Brak snapshotów.\n\nSnapshoty powstają automatycznie przed '
                      'zmianami wykonywanymi przez asystenta AI i przed importem '
                      'planu z pliku.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: snapshots.length,
                  itemBuilder: (ctx, i) {
                    final s = snapshots[i];
                    final isAi = s.label.startsWith('AI:');
                    return ListTile(
                      leading: Icon(
                        isAi
                            ? Icons.smart_toy_outlined
                            : Icons.history_outlined,
                        color: scheme.primary,
                      ),
                      title: Text(s.label,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(df.format(s.savedAt),
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant)),
                      trailing: const Icon(Icons.restore),
                      onTap: () => _restore(s),
                    );
                  },
                ),
    );
  }
}
