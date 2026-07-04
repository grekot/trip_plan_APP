import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/trip_loader.dart';
import '../services/passphrase_store.dart';
import '../services/plan_library_service.dart';
import 'providers.dart';

/// Czy ustawiono hasło deszyfrujące (w secure storage).
class PassphraseNotifier extends StateNotifier<bool> {
  PassphraseNotifier() : super(false) {
    _load();
  }
  Future<void> _load() async {
    state = await PassphraseStore.has();
  }

  Future<void> setPassphrase(String p) async {
    await PassphraseStore.set(p.trim());
    state = true;
  }

  Future<void> clear() async {
    await PassphraseStore.clear();
    state = false;
  }
}

final passphraseProvider =
    StateNotifierProvider<PassphraseNotifier, bool>((ref) => PassphraseNotifier());

/// Stan lokalnej biblioteki planów: pobrane plany + który jest aktywny.
class PlanLibraryState {
  final List<DownloadedPlan> downloaded;
  final String? activeId;
  const PlanLibraryState(this.downloaded, this.activeId);
}

class PlanLibraryNotifier extends StateNotifier<AsyncValue<PlanLibraryState>> {
  final Ref ref;
  PlanLibraryNotifier(this.ref) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      final list = await PlanLibraryService.listDownloaded();
      state = AsyncValue.data(PlanLibraryState(list, TripLoader.activePlanId()));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Ustawia aktywny plan i przeładowuje widok planu.
  Future<void> setActive(String id) async {
    await TripLoader.setActivePlanId(id);
    await ref.read(tripProvider.notifier).reload();
    await refresh();
  }

  /// Pobiera plan z chmury, odszyfrowuje i zapisuje. Aktywuje go, gdy [activate]
  /// lub gdy nie było jeszcze żadnego aktywnego planu. Zwraca id.
  Future<String> download(PlanManifestEntry e, String passphrase,
      {bool activate = false}) async {
    final id = await PlanLibraryService.download(e, passphrase);
    if (activate || TripLoader.activePlanId() == null) {
      await TripLoader.setActivePlanId(id);
    }
    // KLUCZOWE: gdy pobrany plan jest (lub właśnie został) planem AKTYWNYM,
    // przeładuj go z dysku. Bez tego apka trzyma w pamięci starą wersję,
    // a pierwsza edycja nadpisuje świeżo pobrany plik starą treścią.
    if (TripLoader.activePlanId() == id) {
      await ref.read(tripProvider.notifier).reload();
    }
    await refresh();
    return id;
  }

  /// Usuwa pobrany plan; jeśli był aktywny — widok planu przejdzie w stan pusty.
  Future<void> delete(String id) async {
    await PlanLibraryService.delete(id);
    await ref.read(tripProvider.notifier).reload();
    await refresh();
  }
}

final planLibraryProvider =
    StateNotifierProvider<PlanLibraryNotifier, AsyncValue<PlanLibraryState>>(
        (ref) => PlanLibraryNotifier(ref));
