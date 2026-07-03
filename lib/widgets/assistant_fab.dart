import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Pływający przycisk szybkiego dostępu do asystenta AI.
/// Otwiera czat przez push — systemowy „wstecz" wraca na bieżący ekran.
class AssistantFab extends StatelessWidget {
  const AssistantFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'assistant-fab',
      tooltip: 'Asystent AI',
      onPressed: () => context.push('/assistant'),
      child: const Icon(Icons.smart_toy_outlined),
    );
  }
}
