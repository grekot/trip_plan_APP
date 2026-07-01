import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/providers.dart';

class PracticalScreen extends ConsumerWidget {
  const PracticalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripA = ref.watch(tripProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Praktyczne')),
      body: tripA.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Błąd: $e')),
        data: (trip) {
          final p = trip.practical;
          return ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              _winiety(context, p['winiety'] as Map?, scheme),
              _kuchnia(context, p['kuchnia'] as Map?, scheme),
              _budzet(context, p['budzet'] as Map?, scheme),
              _sezon(context, p['sezon'] as List?, scheme),
              _jezyk(context, p['jezyk'] as Map?, scheme),
              _noclegi(context, p['noclegi'] as Map?, scheme),
              _links(context, p['links'] as List?, scheme),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(BuildContext c, IconData ic, String t) {
    final scheme = Theme.of(c).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(children: [
        Icon(ic, color: scheme.primary, size: 22),
        const SizedBox(width: 8),
        Text(t, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: scheme.primary)),
      ]),
    );
  }

  Widget _winiety(BuildContext c, Map? data, ColorScheme scheme) {
    if (data == null) return const SizedBox.shrink();
    final items = (data['items'] as List? ?? []);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle(c, Icons.confirmation_number_outlined, data['title'] as String? ?? 'Winiety'),
      for (final raw in items)
        _linkCard(c, raw['label'] as String? ?? '', raw['url'] as String?,
            note: raw['note'] as String?),
      if (data['note'] != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(data['note'] as String,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ),
    ]);
  }

  Widget _kuchnia(BuildContext c, Map? data, ColorScheme scheme) {
    if (data == null) return const SizedBox.shrink();
    Widget block(String t, List? items) {
      if (items == null || items.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(t,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
          ),
          ...items.map((i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('• '),
                  Expanded(child: Text(i.toString())),
                ]),
              )),
        ],
      );
    }

    final title = data['title'] as String? ?? 'Kuchnia — co spróbować';
    final kategorie = data['kategorie'] as List?;

    // NOWY format (data-driven): `kategorie: [{name, items}]` — dowolne nazwy.
    if (kategorie != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(c, Icons.restaurant_menu, title),
        for (final k in kategorie)
          if (k is Map)
            block(k['name'] as String? ?? '', k['items'] as List?),
      ]);
    }

    // LEGACY format (Słowenia v1): twarde klucze `slodkie/slone/napoje`.
    // Zostawione dla planów, które nie migrowały jeszcze na `kategorie[]`.
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle(c, Icons.restaurant_menu, title),
      block('Słodkie', data['slodkie'] as List?),
      block('Słone', data['slone'] as List?),
      block('Napoje', data['napoje'] as List?),
    ]);
  }

  Widget _budzet(BuildContext c, Map? data, ColorScheme scheme) {
    if (data == null) return const SizedBox.shrink();
    final items = (data['items'] as List? ?? []);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle(c, Icons.savings_outlined, data['title'] as String? ?? 'Budżet'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            for (final raw in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Expanded(child: Text(raw['label'] as String? ?? '')),
                  Text(raw['value'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ),
            const Divider(),
            Row(children: [
              const Expanded(child: Text('Suma', style: TextStyle(fontWeight: FontWeight.w700))),
              Text(data['total'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
      ),
    ]);
  }

  Widget _sezon(BuildContext c, List? items, ColorScheme scheme) {
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle(c, Icons.wb_sunny_outlined, 'Sezon'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items
                .map((i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('• '),
                        Expanded(child: Text(i.toString())),
                      ]),
                    ))
                .toList(),
          ),
        ),
      ),
    ]);
  }

  Widget _jezyk(BuildContext c, Map? data, ColorScheme scheme) {
    if (data == null) return const SizedBox.shrink();
    final slownik = (data['slownik'] as List? ?? []);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle(c, Icons.translate, 'Język'),
      if (data['info'] != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(data['info'] as String, style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: slownik
                .map((s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Expanded(
                            child: Text(s['sl'] as String? ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w700))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(s['pl'] as String? ?? '',
                                style: TextStyle(color: scheme.onSurfaceVariant))),
                      ]),
                    ))
                .toList(),
          ),
        ),
      ),
    ]);
  }

  Widget _noclegi(BuildContext c, Map? data, ColorScheme scheme) {
    if (data == null || data.isEmpty) return const SizedBox.shrink();

    // Mapowanie klucz JSON → ładny tytuł noclegu.
    // Nieznane klucze renderują się z samym kluczem jako tytułem (fallback).
    const titles = <String, String>{
      'kranjska_gora': 'Kranjska Gora (2 noce)',
      'radovljica': 'Radovljica (2 noce)',
      'terme': 'Terme Čatež (3 noce)',
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle(c, Icons.hotel_outlined, 'Noclegi'),
      for (final entry in data.entries)
        if (entry.value is String)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titles[entry.key] ?? entry.key,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(entry.value as String),
              ]),
            ),
          ),
    ]);
  }

  Widget _links(BuildContext c, List? items, ColorScheme scheme) {
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle(c, Icons.link, 'Linki'),
      for (final raw in items) _linkCard(c, raw['label'] as String? ?? '', raw['url'] as String?),
    ]);
  }

  Widget _linkCard(BuildContext c, String label, String? url, {String? note}) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.open_in_new),
        title: Text(label),
        subtitle: note != null ? Text(note) : null,
        onTap: url == null
            ? null
            : () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      ),
    );
  }
}
