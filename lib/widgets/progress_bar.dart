import 'package:flutter/material.dart';

class DayProgressBar extends StatelessWidget {
  final double value;
  final double height;
  const DayProgressBar({super.key, required this.value, this.height = 6});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(children: [
      Container(
        height: height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
      LayoutBuilder(
        builder: (ctx, c) => AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: height,
          width: c.maxWidth * value.clamp(0.0, 1.0),
          decoration: BoxDecoration(
            color: value >= 1.0 ? Colors.green : scheme.primary,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      ),
    ]);
  }
}
