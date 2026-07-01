import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';

class NoteEditor {
  static void show(BuildContext context, WidgetRef ref, String itemId, String initial) {
    final controller = TextEditingController(text: initial);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        return Padding(
          padding: EdgeInsets.only(
              left: 16, right: 16, top: 16, bottom: mq.viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Icon(Icons.sticky_note_2_outlined),
                const SizedBox(width: 8),
                const Expanded(
                    child: Text('Notatka', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                IconButton(
                    icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 6,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Wpisz swoją notatkę…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                if (initial.isNotEmpty)
                  TextButton.icon(
                    onPressed: () async {
                      await ref.read(notesProvider.notifier).setNote(itemId, '');
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Usuń'),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () async {
                    await ref.read(notesProvider.notifier).setNote(itemId, controller.text.trim());
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Zapisz'),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }
}
