# Jak zbudować APK — instrukcja

## Stan obecny

Projekt jest **w pełni gotowy do buildu**. Toolchain (JDK 17, Flutter 3.41.9 stable, Android SDK 36) zainstalowany w `C:\Users\grzegorz.kotarba\dev\`. `flutter doctor` zielony.

Cały kod aplikacji napisany — 8 ekranów, 5 widgetów, 5 providerów Riverpod, JSON loader, pełny `assets/trip.json` z planu wakacji.

`.dart_tool` wyczyszczony, świeży `flutter pub get` wykonany. Wszystko gotowe na build.

## Build APK — od teraz powinien zadziałać

Otwórz **zwykły PowerShell** (Win+R → `powershell`, nie przez Claude) i wykonaj:

```powershell
cd "C:\TMP\Android\slowenia_app"
flutter build apk --release --split-per-abi
```

Pierwszy build potrwa **5–15 minut** (Gradle pobiera ~150 MB, NDK kompiluje natywne wtyczki, AOT-uje Dart).

Po sukcesie zobaczysz w `build\app\outputs\flutter-apk\` trzy pliki:
- `app-armeabi-v7a-release.apk` — 32-bit ARM (starsze telefony)
- `app-arm64-v8a-release.apk` — **64-bit ARM (Twój telefon, ten ściągasz)**
- `app-x86_64-release.apk` — x86 (emulator)

## Wgranie na telefon

1. Skopiuj `app-arm64-v8a-release.apk` (~20-25 MB) na telefon — kabel USB, Google Drive, email, cokolwiek
2. Na telefonie: Ustawienia → Bezpieczeństwo → włącz „Nieznane źródła" dla aplikacji której użyjesz do otwarcia APK (Pliki / Drive / Chrome)
3. Tap APK → Zainstaluj
4. Pierwsze uruchomienie: aplikacja zapyta o datę startu wyjazdu — ustaw

## Jeśli build padnie

### Błędy „Type X not found" (Matrix4, ConsumerWidget itp.)

Stary `.dart_tool` cache. Wykonaj:

```powershell
cd "C:\TMP\Android\slowenia_app"
flutter clean
flutter pub get
flutter build apk --release --split-per-abi
```

### Błąd „java.io.IOException: Unable to establish loopback connection"

Występował tylko w harnessie Claude (Gradle daemon spawn). W normalnym terminalu nie powinien się pojawić. Jeśli mimo to — sprawdź czy nie blokuje go AV lub Defender Application Control.

### Inne

Sprawdź `flutter doctor`. Wszystko powinno być zielone. Jeśli coś jest na czerwono, doinstaluj brakujący komponent.

## Iteracja w przyszłości

### Drobne zmiany w planie (treść)

W apce: Ustawienia → Eksportuj plan → wyślij sobie przez mail/Drive → edytuj JSON na kompie → wyślij z powrotem → Ustawienia → Importuj plan z pliku → potwierdź diff. **Bez rebuilda APK**.

### Zmiany w kodzie (UI, logika)

```powershell
cd "C:\TMP\Android\slowenia_app"
# edytuj pliki w lib/...
flutter build apk --release --split-per-abi
# wgraj nowy APK na telefon
```

Drugi i kolejne buildy są dużo szybsze (~30-60s).

## Pliki w projekcie

```
slowenia_app/
├── pubspec.yaml                         # dependencies
├── android/                             # build config + Manifest z queries dla geo:/tel:/https:
├── assets/
│   └── trip.json                        # CAŁY plan: 6 dni, 100+ punktów, alternatywy treku, atrakcje extra,
│                                        # pakowanie, numery alarmowe, plany B, kuchnia, budżet, słownik
└── lib/
    ├── main.dart                        # bootstrap (Hive init, locale pl_PL)
    ├── app_router.dart                  # go_router config
    ├── theme.dart                       # Material 3, kolory typów punktów
    ├── models/
    │   ├── enums.dart                   # ItemType, ContactType, ExtraCategory
    │   └── trip_models.dart             # Trip, Day, Section, Item, Location, etc.
    ├── data/
    │   └── trip_loader.dart             # load/save JSON, import/export, walidacja, diff
    ├── providers/
    │   └── providers.dart               # 5 providerów Riverpod (trip, progress, notes, packing, settings)
    ├── widgets/
    │   ├── item_tile.dart               # wiersz punktu z checkbox + ikoną + mapą + notatką
    │   ├── location_button.dart         # tap → geo: intent → Google Maps
    │   ├── progress_bar.dart            # pasek postępu dnia
    │   ├── note_editor.dart             # bottom sheet do notatek
    │   └── emergency_button.dart        # tap → tel: intent → dialer
    └── screens/
        ├── home_screen.dart             # „Dzisiaj" — aktywny dzień + onboarding + drawer
        ├── days_overview_screen.dart    # lista 6 dni z paskami postępu
        ├── day_detail_screen.dart       # szczegóły dnia + sekcje + alternatywy + dodaj punkt
        ├── extras_screen.dart           # 7 atrakcji extra z filtrem po kategorii
        ├── packing_screen.dart          # checklist pakowania
        ├── practical_screen.dart        # winiety, kuchnia, budżet, sezon, słownik, noclegi, linki
        ├── emergency_screen.dart        # tap-to-call dla 112/ambasady/AMZS + plany B
        └── settings_screen.dart         # data startu + import/export/reset planu i postępu
```

## Co aplikacja umie

- Odznaczanie punktów z paskiem postępu dnia
- Notatki użytkownika do każdego punktu (persystowane w Hive)
- Mapa: tap → otwiera Google Maps z pinem
- Tap-to-call numerów alarmowych
- Tryb „dzisiaj" — pokazuje bieżący dzień na podstawie daty startu
- Przed wyjazdem: licznik T-X dni + checklist pakowania
- Custom items: dodaj własny punkt do sekcji
- Ukrywanie punktów (long-press → ukryj)
- Eksport/import planu jako JSON
- Działanie offline (mapy otwierają się externally)
- Filtr atrakcji extra po kategorii (krótka przerwa / pół dnia / w upały / itp.)
- Slowenian → polski słownik
- Plany awaryjne (deszcz/upał/tłok)

## Konfiguracja toolchainu — w razie czego

```
JAVA_HOME = C:\Users\grzegorz.kotarba\dev\jdk-17.0.19+10
ANDROID_HOME = C:\Users\grzegorz.kotarba\dev\android-sdk
Flutter SDK = C:\Users\grzegorz.kotarba\dev\flutter
PATH zawiera: %JAVA_HOME%\bin, %ANDROID_HOME%\platform-tools, %ANDROID_HOME%\cmdline-tools\latest\bin, $Flutter\bin
```

Te zmienne są ustawione jako USER env vars (persystentne, bez admina).
