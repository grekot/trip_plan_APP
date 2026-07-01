import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import 'dart:io' show Platform;
import '../services/ota_service.dart';

/// Otwiera dialog sprawdzania i pobierania aktualizacji.
///
/// Windows/desktop: pokazuje wersję i przycisk „Otwórz stronę wydań" —
/// natywne OTA nie działa poza Androidem.
///
/// Android: sprawdza GitHub Releases, jeśli nowa wersja → pyta o pobranie,
/// pokazuje postęp, uruchamia instalatora.
Future<void> showUpdateDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _UpdateDialog(),
  );
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog();

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

enum _Phase { checking, upToDate, hasUpdate, downloading, error, desktop }

class _UpdateDialogState extends State<_UpdateDialog> {
  _Phase _phase = _Phase.checking;
  UpdateInfo? _info;
  String? _errorMsg;
  int _percent = 0;
  StreamSubscription<OtaEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (!kIsWeb && !Platform.isAndroid) {
      // Desktop: pokaż tylko info + link do releases.
      try {
        final info = await OtaService.checkForUpdate();
        if (!mounted) return;
        setState(() {
          _info = info;
          _phase = _Phase.desktop;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _phase = _Phase.desktop;
          _errorMsg = 'Nie udało się sprawdzić: $e';
        });
      }
      return;
    }

    try {
      final info = await OtaService.checkForUpdate();
      if (!mounted) return;
      if (info == null || !info.isNewer || info.apkUrl == null) {
        setState(() {
          _info = info;
          _phase = _Phase.upToDate;
        });
      } else {
        setState(() {
          _info = info;
          _phase = _Phase.hasUpdate;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _errorMsg = e.toString();
      });
    }
  }

  Future<void> _download() async {
    final info = _info;
    if (info == null || info.apkUrl == null) return;
    setState(() {
      _phase = _Phase.downloading;
      _percent = 0;
    });

    try {
      // Rozwijamy 302 GitHub → objects.githubusercontent.com. Bez tego niektóre
      // urządzenia pobierają śmieciowy plik i instalacja wisi.
      final direct = await OtaService.resolveFinalUrl(info.apkUrl!);

      _sub = OtaService.downloadAndInstall(direct, info.latestVersion).listen(
        (event) {
          if (!mounted) return;
          if (event.status == OtaStatus.DOWNLOADING) {
            final v = int.tryParse(event.value ?? '') ?? 0;
            setState(() {
              _percent = v;
            });
          } else if (OtaService.isErrorStatus(event.status)) {
            setState(() {
              _phase = _Phase.error;
              _errorMsg = '${event.status}: ${event.value}';
            });
          } else if (event.status == OtaStatus.INSTALLING) {
            // Instalator systemowy odpalony — dialog można zamknąć.
            Navigator.of(context).maybePop();
          }
        },
        onError: (Object e) {
          if (!mounted) return;
          setState(() {
            _phase = _Phase.error;
            _errorMsg = e.toString();
          });
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _errorMsg = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.checking:
        return const AlertDialog(
          content: SizedBox(
            height: 80,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Sprawdzam GitHub Releases…'),
                ],
              ),
            ),
          ),
        );

      case _Phase.upToDate:
        return AlertDialog(
          title: const Text('Masz najnowszą wersję'),
          content: Text(
            _info == null
                ? 'Nie znaleziono nowszej wersji.'
                : 'Aktualna: v${_info!.currentVersion}\nNajnowsza opublikowana: v${_info!.latestVersion.isEmpty ? '—' : _info!.latestVersion}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );

      case _Phase.hasUpdate:
        final info = _info!;
        return AlertDialog(
          title: Text('Nowa wersja: v${info.latestVersion}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Masz: v${info.currentVersion}'),
                const SizedBox(height: 12),
                if (info.releaseNotes != null && info.releaseNotes!.trim().isNotEmpty) ...[
                  const Text(
                    'Co nowego:',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    info.releaseNotes!,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text(
                  'Aplikacja pobierze APK i uruchomi systemowego instalatora. '
                  'Może być potrzebne raz zezwolenie na instalację z tego źródła.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Później'),
            ),
            FilledButton.icon(
              onPressed: _download,
              icon: const Icon(Icons.download),
              label: const Text('Pobierz i zainstaluj'),
            ),
          ],
        );

      case _Phase.downloading:
        return AlertDialog(
          title: Text('Pobieram v${_info?.latestVersion ?? ''}…'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: _percent > 0 ? _percent / 100 : null,
                ),
                const SizedBox(height: 12),
                Text('$_percent%'),
                const SizedBox(height: 8),
                const Text(
                  'Po pobraniu otworzy się systemowy instalator.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );

      case _Phase.error:
        return AlertDialog(
          title: const Text('Błąd aktualizacji'),
          content: Text(_errorMsg ?? 'Nieznany błąd'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
            if (_info?.releaseUrl != null)
              FilledButton.tonal(
                onPressed: () async {
                  await OtaService.openReleasesPage();
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Otwórz w przeglądarce'),
              ),
          ],
        );

      case _Phase.desktop:
        final info = _info;
        return AlertDialog(
          title: const Text('Aktualizacja'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (info != null) ...[
                Text('Aktualna: v${info.currentVersion}'),
                Text('Najnowsza: v${info.latestVersion.isEmpty ? '—' : info.latestVersion}'),
                const SizedBox(height: 8),
                if (info.isNewer)
                  const Text(
                    'Dostępna nowa wersja — pobierz ZIP z Windows na stronie wydań i zastąp folder.',
                    style: TextStyle(color: Color(0xFFC77700)),
                  )
                else
                  const Text('Masz najnowszą wersję.'),
              ] else if (_errorMsg != null)
                Text(_errorMsg!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              const Text(
                'Wersja Windows nie ma automatycznej aktualizacji — otwórz stronę Releases '
                'i pobierz ZIP ręcznie.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Zamknij'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await OtaService.openReleasesPage();
                if (mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Otwórz stronę wydań'),
            ),
          ],
        );
    }
  }
}
