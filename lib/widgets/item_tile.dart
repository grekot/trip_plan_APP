import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trip_models.dart';
import '../models/enums.dart';
import '../providers/providers.dart';
import '../screens/item_edit_screen.dart';
import '../theme.dart';
import 'location_button.dart';
import 'note_editor.dart';

class ItemTile extends ConsumerWidget {
  final Item item;
  const ItemTile({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final checked = ref.watch(progressProvider)[item.id] ?? false;
    final note = ref.watch(notesProvider)[item.id] ?? '';
    final typeColor = TypeStyling.colorFor(item.type, scheme);
    final isInfo = item.type == ItemType.info;

    return Opacity(
      opacity: item.hidden ? 0.45 : 1.0,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isInfo ? null : () => ref.read(progressProvider.notifier).toggle(item.id),
          onLongPress: () => _showActions(context, ref),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isInfo)
                  Checkbox(
                    value: checked,
                    onChanged: (_) => ref.read(progressProvider.notifier).toggle(item.id),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 4, 0),
                    child: Icon(TypeStyling.iconFor(item.type), color: typeColor, size: 22),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (!isInfo)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(TypeStyling.iconFor(item.type), color: typeColor, size: 18),
                            ),
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                decoration: checked ? TextDecoration.lineThrough : null,
                                color: checked ? scheme.onSurfaceVariant : scheme.onSurface,
                              ),
                            ),
                          ),
                          if (item.userAdded)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(Icons.edit_note, size: 18, color: scheme.tertiary),
                            ),
                        ],
                      ),
                      if (item.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.description!,
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                        ),
                      ],
                      if (item.tips.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        ...item.tips.map((t) => Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 6, right: 6),
                                    child: Icon(Icons.fiber_manual_record, size: 6),
                                  ),
                                  Expanded(
                                    child: Text(t,
                                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                                  ),
                                ],
                              ),
                            )),
                      ],
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.sticky_note_2_outlined, size: 14, color: scheme.onSecondaryContainer),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(note,
                                    style: TextStyle(fontSize: 12, color: scheme.onSecondaryContainer)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (item.location != null || item.locations.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (item.location != null) LocationButton(location: item.location!),
                            ...item.locations.map((l) => LocationButton(location: l)),
                          ],
                        ),
                      ],
                      if (item.costEur != null || item.duration != null) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (item.costEur != null)
                              _chip(context, Icons.euro, '${item.costEur} €'),
                            if (item.duration != null)
                              _chip(context, Icons.timer_outlined, _humanDuration(item.duration!)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Notatka',
                  icon: Icon(note.isEmpty ? Icons.note_add_outlined : Icons.edit_note),
                  onPressed: () => NoteEditor.show(context, ref, item.id, note),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, IconData ic, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ic, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  String _humanDuration(String iso) {
    final r = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?');
    final m = r.firstMatch(iso);
    if (m == null) return iso;
    final h = m.group(1);
    final min = m.group(2);
    if (h != null && min != null) return '${h}h ${min}min';
    if (h != null) return '${h}h';
    if (min != null) return '${min}min';
    return iso;
  }

  void _showActions(BuildContext context, WidgetRef ref) {
    // Znajdź ścieżkę do punktu w drzewie (dayIdx, secIdx, itemIdx) — potrzebne do nawigacji do edytora.
    final trip = ref.read(tripProvider).value;
    int dayIdx = -1, secIdx = -1, itemIdx = -1;
    bool isAlternative = false;
    if (trip != null) {
      outer:
      for (int di = 0; di < trip.days.length; di++) {
        final d = trip.days[di];
        for (int si = 0; si < d.sections.length; si++) {
          final s = d.sections[si];
          for (int ii = 0; ii < s.items.length; ii++) {
            if (s.items[ii].id == item.id) {
              dayIdx = di; secIdx = si; itemIdx = ii;
              break outer;
            }
          }
        }
        for (int ai = 0; ai < d.alternatives.length; ai++) {
          if (d.alternatives[ai].id == item.id) {
            dayIdx = di; itemIdx = ai; isAlternative = true;
            break outer;
          }
        }
      }
    }

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            if (dayIdx >= 0)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edytuj punkt'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ItemEditScreen(
                      dayIdx: dayIdx, sectionIdx: secIdx, itemIdx: itemIdx, isAlternative: isAlternative,
                    ),
                  ));
                },
              ),
            if (dayIdx >= 0 && !isAlternative)
              ListTile(
                leading: const Icon(Icons.content_copy),
                title: const Text('Duplikuj punkt'),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(tripProvider.notifier).duplicateItem(dayIdx, secIdx, itemIdx);
                },
              ),
            ListTile(
              leading: Icon(item.hidden ? Icons.visibility : Icons.visibility_off),
              title: Text(item.hidden ? 'Pokaż punkt' : 'Ukryj punkt'),
              onTap: () {
                Navigator.pop(context);
                ref.read(tripProvider.notifier).toggleHidden(item.id);
              },
            ),
            if (dayIdx >= 0)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Usuń punkt', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Usunąć punkt?'),
                      content: Text('Usunąć „${item.title}"?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Usuń'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    if (isAlternative) {
                      await ref.read(tripProvider.notifier).deleteAlternative(dayIdx, itemIdx);
                    } else {
                      await ref.read(tripProvider.notifier).deleteItem(dayIdx, secIdx, itemIdx);
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
