import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/enums.dart';
import '../models/trip_models.dart';
import '../providers/providers.dart';
import '../theme.dart';
import 'location_picker_screen.dart';

/// Edycja punktu (Item) w drzewie dni/sekcji.
/// Otwierana przez ItemTile long-press lub przycisk edycji.
class ItemEditScreen extends ConsumerStatefulWidget {
  final int dayIdx;
  final int sectionIdx;
  final int itemIdx;
  final bool isAlternative; // gdy true: edytujemy day.alternatives[itemIdx], sectionIdx ignorowany
  const ItemEditScreen({
    super.key,
    required this.dayIdx,
    required this.sectionIdx,
    required this.itemIdx,
    this.isAlternative = false,
  });

  @override
  ConsumerState<ItemEditScreen> createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends ConsumerState<ItemEditScreen> {
  late TextEditingController _titleCtl;
  late TextEditingController _descCtl;
  late TextEditingController _durationCtl;
  late TextEditingController _costCtl;
  late TextEditingController _idCtl;
  late ItemType _type;
  late Location? _location;
  late List<String> _tips;
  late bool _hidden;

  bool _dirty = false;
  Item? _orig;

  @override
  void initState() {
    super.initState();
    final t = ref.read(tripProvider).value;
    if (t == null) {
      _initEmpty();
      return;
    }
    Item? src;
    try {
      if (widget.isAlternative) {
        src = t.days[widget.dayIdx].alternatives[widget.itemIdx];
      } else {
        src = t.days[widget.dayIdx].sections[widget.sectionIdx].items[widget.itemIdx];
      }
    } catch (_) {
      src = null;
    }
    _orig = src;
    if (src != null) {
      _idCtl = TextEditingController(text: src.id);
      _titleCtl = TextEditingController(text: src.title);
      _descCtl = TextEditingController(text: src.description ?? '');
      _durationCtl = TextEditingController(text: src.duration ?? '');
      _costCtl = TextEditingController(text: src.costEur?.toString() ?? '');
      _type = src.type;
      _location = src.location;
      _tips = [...src.tips];
      _hidden = src.hidden;
    } else {
      _initEmpty();
    }
  }

  void _initEmpty() {
    _idCtl = TextEditingController();
    _titleCtl = TextEditingController();
    _descCtl = TextEditingController();
    _durationCtl = TextEditingController();
    _costCtl = TextEditingController();
    _type = ItemType.sightseeing;
    _location = null;
    _tips = [];
    _hidden = false;
  }

  @override
  void dispose() {
    _idCtl.dispose();
    _titleCtl.dispose();
    _descCtl.dispose();
    _durationCtl.dispose();
    _costCtl.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() { _dirty = true; });
  }

  bool _validateDuration(String v) {
    if (v.isEmpty) return true;
    return RegExp(r'^PT(\d+H)?(\d+M)?$').hasMatch(v);
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initial: _location,
          title: _location == null ? 'Dodaj lokalizację' : 'Edytuj lokalizację',
        ),
      ),
    );
    if (result == null && !mounted) return;
    if (isRemoveResult(result)) {
      setState(() { _location = null; _dirty = true; });
    } else if (result is Location) {
      setState(() { _location = result; _dirty = true; });
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Odrzucić zmiany?'),
        content: const Text('Masz niezapisane zmiany. Co chcesz zrobić?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Wróć do edycji')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Odrzuć')),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _save() async {
    final title = _titleCtl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tytuł nie może być pusty')));
      return;
    }
    if (!_validateDuration(_durationCtl.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Niepoprawny format czasu trwania (np. PT1H30M)')));
      return;
    }
    final cost = _costCtl.text.trim().isEmpty ? null : int.tryParse(_costCtl.text.trim());
    final updated = Item(
      id: _idCtl.text.trim().isEmpty ? (_orig?.id ?? 'custom.${DateTime.now().millisecondsSinceEpoch}') : _idCtl.text.trim(),
      title: title,
      description: _descCtl.text.trim().isEmpty ? null : _descCtl.text.trim(),
      type: _type,
      location: _location,
      locations: _orig?.locations ?? [],
      costEur: cost,
      duration: _durationCtl.text.trim().isEmpty ? null : _durationCtl.text.trim(),
      tips: _tips,
      hidden: _hidden,
      userAdded: _orig?.userAdded ?? true,
    );
    if (widget.isAlternative) {
      await ref.read(tripProvider.notifier).updateAlternative(widget.dayIdx, widget.itemIdx, updated);
    } else {
      await ref.read(tripProvider.notifier).updateItem(widget.dayIdx, widget.sectionIdx, widget.itemIdx, updated);
    }
    if (mounted) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zapisano')));
    }
  }

  Future<void> _deleteItem() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Usunąć punkt?'),
        content: Text('Usunąć „${_orig?.title ?? _titleCtl.text}"? Tej operacji nie można cofnąć (chociaż możesz odzyskać przez „Przywróć domyślny plan").'),
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
    if (ok != true) return;
    if (widget.isAlternative) {
      await ref.read(tripProvider.notifier).deleteAlternative(widget.dayIdx, widget.itemIdx);
    } else {
      await ref.read(tripProvider.notifier).deleteItem(widget.dayIdx, widget.sectionIdx, widget.itemIdx);
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _duplicateItem() async {
    if (widget.isAlternative) return;
    await ref.read(tripProvider.notifier).duplicateItem(widget.dayIdx, widget.sectionIdx, widget.itemIdx);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard()) {
          if (mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_orig == null ? 'Nowy punkt' : 'Edytuj punkt'),
          actions: [
            if (_orig != null) PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) {
                if (v == 'duplicate') _duplicateItem();
                if (v == 'delete') _deleteItem();
              },
              itemBuilder: (_) => [
                if (!widget.isAlternative)
                  const PopupMenuItem(value: 'duplicate', child: Row(children:[Icon(Icons.content_copy, size:20), SizedBox(width:8), Text('Duplikuj')])),
                const PopupMenuItem(value: 'delete', child: Row(children:[Icon(Icons.delete_outline, size:20, color: Colors.red), SizedBox(width:8), Text('Usuń', style: TextStyle(color: Colors.red))])),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonalIcon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Zapisz'),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextField(
              controller: _titleCtl,
              decoration: const InputDecoration(labelText: 'Tytuł *', border: OutlineInputBorder()),
              textInputAction: TextInputAction.next,
              onChanged: (_) => _markDirty(),
            ),
            const SizedBox(height: 12),
            // Type
            DropdownButtonFormField<ItemType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Typ punktu', border: OutlineInputBorder()),
              items: ItemType.values.map((t) => DropdownMenuItem(
                value: t,
                child: Row(children: [
                  Icon(TypeStyling.iconFor(t), color: TypeStyling.colorFor(t, Theme.of(context).colorScheme), size: 20),
                  const SizedBox(width: 8),
                  Text(TypeStyling.labelFor(t)),
                ]),
              )).toList(),
              onChanged: (v) => setState(() { _type = v ?? ItemType.info; _dirty = true; }),
            ),
            const SizedBox(height: 12),
            // Description
            TextField(
              controller: _descCtl,
              decoration: const InputDecoration(labelText: 'Opis', border: OutlineInputBorder()),
              maxLines: 4,
              onChanged: (_) => _markDirty(),
            ),
            const SizedBox(height: 16),
            // Duration + Cost
            Row(children: [
              Expanded(child: TextField(
                controller: _durationCtl,
                decoration: const InputDecoration(
                  labelText: 'Czas (ISO 8601)',
                  hintText: 'PT1H30M',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _markDirty(),
              )),
              const SizedBox(width: 8),
              Expanded(child: TextField(
                controller: _costCtl,
                decoration: const InputDecoration(
                  labelText: 'Koszt (€)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => _markDirty(),
              )),
            ]),
            const SizedBox(height: 16),
            // Location
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.place, size: 18),
                    const SizedBox(width: 6),
                    const Text('LOKALIZACJA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  ]),
                  const SizedBox(height: 8),
                  if (_location == null)
                    OutlinedButton.icon(
                      onPressed: _pickLocation,
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('Dodaj lokalizację (mapa)'),
                    )
                  else ...[
                    Text(_location!.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${_location!.lat.toStringAsFixed(4)}, ${_location!.lng.toStringAsFixed(4)}',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, children: [
                      OutlinedButton.icon(onPressed: _pickLocation, icon: const Icon(Icons.edit_location_alt_outlined, size: 16), label: const Text('Edytuj')),
                      TextButton.icon(
                        onPressed: () => setState(() { _location = null; _dirty = true; }),
                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        label: const Text('Usuń', style: TextStyle(color: Colors.red)),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Tips
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡 TIPY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  for (int i = 0; i < _tips.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Expanded(child: TextField(
                          controller: TextEditingController(text: _tips[i])
                            ..selection = TextSelection.collapsed(offset: _tips[i].length),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          ),
                          onChanged: (v) { _tips[i] = v; _dirty = true; },
                        )),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() { _tips.removeAt(i); _dirty = true; }),
                        ),
                      ]),
                    ),
                  TextButton.icon(
                    onPressed: () => setState(() { _tips.add(''); _dirty = true; }),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Dodaj tip'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Hidden toggle
            SwitchListTile.adaptive(
              value: _hidden,
              onChanged: (v) => setState(() { _hidden = v; _dirty = true; }),
              title: const Text('Ukryty'),
              subtitle: const Text('Schowany w głównym widoku (dostępny w „Pokaż ukryte")'),
              contentPadding: EdgeInsets.zero,
            ),
            // ID (read-only-ish, for ref)
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              title: const Text('Zaawansowane', style: TextStyle(fontSize: 13)),
              children: [
                TextField(
                  controller: _idCtl,
                  decoration: InputDecoration(
                    labelText: 'ID (stabilny identyfikator)',
                    helperText: _orig != null ? 'Nie zmieniaj — notatki/odznaczenia są kluczowane po ID' : 'Pozostaw puste żeby wygenerować',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => _markDirty(),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
