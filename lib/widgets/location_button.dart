import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/trip_models.dart';

class LocationButton extends StatelessWidget {
  final Location location;
  final bool compact;
  const LocationButton({super.key, required this.location, this.compact = false});

  Future<void> _open(BuildContext context) async {
    final name = Uri.encodeComponent(location.name);
    final geo = Uri.parse('geo:${location.lat},${location.lng}?q=${location.lat},${location.lng}($name)');
    final https = Uri.parse('https://www.google.com/maps/search/?api=1&query=${location.lat},${location.lng}');
    try {
      if (await canLaunchUrl(geo)) {
        await launchUrl(geo, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    await launchUrl(https, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return IconButton(
        tooltip: 'Otwórz w mapach: ${location.name}',
        icon: const Icon(Icons.map_outlined),
        onPressed: () => _open(context),
      );
    }
    return OutlinedButton.icon(
      onPressed: () => _open(context),
      icon: const Icon(Icons.map_outlined, size: 18),
      label: Text(location.name, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }
}
