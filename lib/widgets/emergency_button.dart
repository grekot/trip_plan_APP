import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyButton extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  const EmergencyButton({
    super.key,
    required this.label,
    required this.value,
    this.icon = Icons.phone,
    this.color,
  });

  static bool get _isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  Future<void> _onTap(BuildContext context) async {
    final clean = value.replaceAll(RegExp(r'[^0-9+]'), '');

    // Na desktopie (Windows/macOS/Linux) `tel:` jest słabo wspierany — zamiast tego
    // kopiujemy numer do schowka i pokazujemy SnackBar.
    if (_isDesktop) {
      await Clipboard.setData(ClipboardData(text: clean));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Skopiowano numer $clean do schowka'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final uri = Uri(scheme: 'tel', path: clean);
    try {
      final ok = await launchUrl(uri);
      if (!ok) {
        await Clipboard.setData(ClipboardData(text: clean));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Nie udało się otworzyć dialer-a — numer $clean w schowku')),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: clean));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Numer $clean w schowku')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = color ?? scheme.errorContainer;
    final fg = color != null ? Colors.white : scheme.onErrorContainer;
    return Card(
      color: bg,
      child: InkWell(
        onTap: () => _onTap(context),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(icon, size: 32, color: fg),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: fg)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: fg)),
                ],
              ),
            ),
            Icon(_isDesktop ? Icons.copy : Icons.phone_forwarded, color: fg),
          ]),
        ),
      ),
    );
  }
}
