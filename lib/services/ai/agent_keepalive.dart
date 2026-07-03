import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Utrzymuje proces apki przy życiu, gdy agent AI pracuje, a użytkownik
/// zrzuci apkę w tło. Android zamraża proces w tle (Doze/App Standby) i zrywa
/// połączenia HTTP w trakcie długiej tury agenta — foreground service
/// z powiadomieniem wyłącza to zamrażanie na czas pracy.
///
/// Serwis nie uruchamia żadnego osobnego izolatu (brak callbacku) — pętla
/// agenta dalej działa w głównym izolacie; powiadomienie tylko „przypina"
/// proces. Start przy wysłaniu wiadomości, stop po zakończeniu tury.
class AgentKeepalive {
  static bool _inited = false;

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  static Future<void> start() async {
    if (!_supported) return;
    try {
      if (!_inited) {
        FlutterForegroundTask.init(
          androidNotificationOptions: AndroidNotificationOptions(
            channelId: 'ai_agent_keepalive',
            channelName: 'Asystent AI',
            channelDescription:
                'Utrzymuje połączenie, gdy asystent AI pracuje w tle',
            channelImportance: NotificationChannelImportance.LOW,
            priority: NotificationPriority.LOW,
          ),
          iosNotificationOptions: const IOSNotificationOptions(),
          foregroundTaskOptions: ForegroundTaskOptions(
            eventAction: ForegroundTaskEventAction.nothing(),
          ),
        );
        _inited = true;
      }
      // Android 13+: powiadomienie serwisu wymaga zgody na notyfikacje.
      final perm = await FlutterForegroundTask.checkNotificationPermission();
      if (perm != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
      if (await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.startService(
        notificationTitle: 'Asystent AI pracuje…',
        notificationText:
            'Możesz przejść do innych aplikacji — dam znać, gdy skończę.',
      );
    } catch (_) {
      // Brak zgody na powiadomienia / egzotyczny ROM — agent zadziała
      // normalnie na pierwszym planie, tylko bez ochrony przed tłem.
    }
  }

  static Future<void> stop() async {
    if (!_supported) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {}
  }
}
