import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/enums.dart';
import '../models/trip_models.dart';
import '../providers/providers.dart';

/// Edycja listy pozycji pakowania.
class PackingEditScreen extends ConsumerWidget {
  const PackingEditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tripProvider).value;
    if (t == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edycja: Pakowanie'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _showEdit(context, ref, null)),
        ],
      ),
      body: ListView.builder(
        itemCount: t.packing.length,
        itemBuilder: (ctx, i) {
          final p = t.packing[i];
          return Dismissible(
            key: ValueKey(p.id),
            background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(title: const Text('Usunąć?'), content: Text(p.text),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error), child: const Text('Usuń')),
                  ]),
              );
              if (ok == true) {
                await ref.read(tripProvider.notifier).deletePackingItem(i);
                return true;
              }
              return false;
            },
            child: ListTile(
              leading: Icon(Icons.check_box_outline_blank, color: Theme.of(context).colorScheme.outline),
              title: Text(p.text),
              subtitle: Text(p.category, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              trailing: const Icon(Icons.edit, size: 18),
              onTap: () => _showEdit(context, ref, i),
            ),
          );
        },
      ),
    );
  }

  void _showEdit(BuildContext context, WidgetRef ref, int? idx) {
    final t = ref.read(tripProvider).value!;
    final p = idx != null ? t.packing[idx] : null;
    final textCtl = TextEditingController(text: p?.text ?? '');
    final catCtl = TextEditingController(text: p?.category ?? 'Ogólnie');
    final categories = t.packing.map((x) => x.category).toSet().toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(p == null ? 'Nowa pozycja pakowania' : 'Edytuj pozycję', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(controller: textCtl, autofocus: true, decoration: const InputDecoration(labelText: 'Treść', border: OutlineInputBorder()), maxLines: 2),
            const SizedBox(height: 8),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: catCtl.text),
              optionsBuilder: (v) => categories.where((c) => c.toLowerCase().contains(v.text.toLowerCase())),
              onSelected: (v) => catCtl.text = v,
              fieldViewBuilder: (ctx, ctrl, fn, _) {
                ctrl.text = catCtl.text;
                return TextField(
                  controller: ctrl, focusNode: fn,
                  decoration: const InputDecoration(labelText: 'Kategoria', border: OutlineInputBorder()),
                  onChanged: (v) => catCtl.text = v,
                );
              },
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
              const SizedBox(width: 6),
              FilledButton(onPressed: () async {
                if (textCtl.text.trim().isEmpty) return;
                final newItem = PackingItem(
                  id: p?.id ?? 'custom.${const Uuid().v4()}',
                  category: catCtl.text.trim().isEmpty ? 'Ogólnie' : catCtl.text.trim(),
                  text: textCtl.text.trim(),
                  userAdded: p?.userAdded ?? true,
                );
                if (idx != null) {
                  await ref.read(tripProvider.notifier).updatePackingItem(idx, newItem);
                } else {
                  await ref.read(tripProvider.notifier).addPackingItem(newItem);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              }, child: Text(p == null ? 'Dodaj' : 'Zapisz')),
            ]),
          ]),
        );
      },
    );
  }
}

/// Edycja kontaktów alarmowych.
class EmergencyEditScreen extends ConsumerWidget {
  const EmergencyEditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tripProvider).value;
    if (t == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edycja: Numery alarmowe'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => _showEdit(context, ref, null))],
      ),
      body: ListView.builder(
        itemCount: t.emergency.length,
        itemBuilder: (ctx, i) {
          final e = t.emergency[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.phone),
              title: Text(e.label),
              subtitle: Text(e.value),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _showEdit(context, ref, i)),
                IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), onPressed: () async {
                  final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
                    title: const Text('Usunąć?'), content: Text(e.label),
                    actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error), child: const Text('Usuń'))],
                  ));
                  if (ok == true) await ref.read(tripProvider.notifier).deleteEmergency(i);
                }),
              ]),
            ),
          );
        },
      ),
    );
  }

  void _showEdit(BuildContext context, WidgetRef ref, int? idx) {
    final t = ref.read(tripProvider).value!;
    final e = idx != null ? t.emergency[idx] : null;
    final labelCtl = TextEditingController(text: e?.label ?? '');
    final valueCtl = TextEditingController(text: e?.value ?? '');
    ContactType type = e?.type ?? ContactType.phone;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setState) => AlertDialog(
      title: Text(e == null ? 'Nowy kontakt' : 'Edytuj kontakt'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: labelCtl, autofocus: true, decoration: const InputDecoration(labelText: 'Etykieta', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: valueCtl, decoration: const InputDecoration(labelText: 'Numer/email', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
        const SizedBox(height: 8),
        DropdownButtonFormField<ContactType>(
          initialValue: type,
          decoration: const InputDecoration(labelText: 'Typ', border: OutlineInputBorder()),
          items: ContactType.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label))).toList(),
          onChanged: (v) { if (v != null) setState(() { type = v; }); },
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
        FilledButton(onPressed: () async {
          final newContact = EmergencyContact(
            id: e?.id ?? 'custom.${const Uuid().v4()}',
            label: labelCtl.text.trim(), value: valueCtl.text.trim(), type: type,
          );
          if (idx != null) {
            await ref.read(tripProvider.notifier).updateEmergency(idx, newContact);
          } else {
            await ref.read(tripProvider.notifier).addEmergency(newContact);
          }
          if (ctx.mounted) Navigator.pop(ctx);
        }, child: Text(e == null ? 'Dodaj' : 'Zapisz')),
      ],
    )));
  }
}

/// Edycja planów B.
class ContingencyEditScreen extends ConsumerWidget {
  const ContingencyEditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tripProvider).value;
    if (t == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edycja: Plany B'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => _showEdit(context, ref, null))],
      ),
      body: ListView.builder(
        itemCount: t.contingency.length,
        itemBuilder: (ctx, i) {
          final c = t.contingency[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.umbrella),
              title: Text(c.trigger),
              subtitle: Text('${c.options.length} opcji', style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showEdit(context, ref, i),
            ),
          );
        },
      ),
    );
  }

  void _showEdit(BuildContext context, WidgetRef ref, int? idx) {
    final t = ref.read(tripProvider).value!;
    final c = idx != null ? t.contingency[idx] : null;
    final trigCtl = TextEditingController(text: c?.trigger ?? '');
    final options = <String>[...(c?.options ?? <String>[])];

    Navigator.of(context).push(MaterialPageRoute(builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        return Scaffold(
          appBar: AppBar(
            title: Text(c == null ? 'Nowy plan B' : 'Edytuj plan B'),
            actions: [
              if (idx != null)
                IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async {
                  await ref.read(tripProvider.notifier).deleteContingency(idx);
                  if (ctx.mounted) Navigator.pop(ctx);
                }),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    if (trigCtl.text.trim().isEmpty) return;
                    final newC = Contingency(
                      id: c?.id ?? 'custom.${const Uuid().v4()}',
                      trigger: trigCtl.text.trim(),
                      options: options.where((o) => o.trim().isNotEmpty).toList(),
                    );
                    if (idx != null) {
                      await ref.read(tripProvider.notifier).updateContingency(idx, newC);
                    } else {
                      await ref.read(tripProvider.notifier).addContingency(newC);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Zapisz'),
                ),
              ),
            ],
          ),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            TextField(controller: trigCtl, decoration: const InputDecoration(labelText: 'Trigger (sytuacja)', hintText: 'np. Deszcz przy treku', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(8)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('OPCJE (CO ROBIĆ)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                for (int i = 0; i < options.length; i++)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
                    Expanded(child: TextField(
                      controller: TextEditingController(text: options[i])..selection = TextSelection.collapsed(offset: options[i].length),
                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                      maxLines: 2, minLines: 1,
                      onChanged: (v) => options[i] = v,
                    )),
                    IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() { options.removeAt(i); })),
                  ])),
                TextButton.icon(icon: const Icon(Icons.add, size: 18), label: const Text('Dodaj opcję'), onPressed: () => setState(() { options.add(''); })),
              ]),
            ),
          ]),
        );
      });
    }));
  }
}
