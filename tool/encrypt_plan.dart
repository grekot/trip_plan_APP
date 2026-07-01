import 'dart:io';
import 'package:slowenia_app/services/crypto_service.dart';

/// Narzędzie PC do szyfrowania/odszyfrowania planów podróży dla repo `trip_plans`.
///
/// Używa dokładnie tego samego [CryptoService] co apka, więc format jest
/// gwarantowanie zgodny.
///
/// Użycie:
///   dart run tool/encrypt_plan.dart enc <plik-hasla> <wejscie.json> <wyjscie.enc>
///   dart run tool/encrypt_plan.dart dec <plik-hasla> <wejscie.enc>  <wyjscie.json>
///
/// `<plik-hasla>` to ścieżka do pliku z hasłem (np.
/// C:\TMP\Android\plans-workspace\passphrase.txt) — hasło NIE jest podawane
/// w linii poleceń, żeby nie trafiło do historii shella.
Future<void> main(List<String> args) async {
  if (args.length != 4 || (args[0] != 'enc' && args[0] != 'dec')) {
    stderr.writeln('Użycie:');
    stderr.writeln('  dart run tool/encrypt_plan.dart enc <plik-hasla> <wejscie.json> <wyjscie.enc>');
    stderr.writeln('  dart run tool/encrypt_plan.dart dec <plik-hasla> <wejscie.enc>  <wyjscie.json>');
    exitCode = 2;
    return;
  }
  final mode = args[0];
  final passFile = File(args[1]);
  final input = File(args[2]);
  final output = File(args[3]);

  if (!passFile.existsSync()) {
    stderr.writeln('Brak pliku z hasłem: ${passFile.path}');
    exitCode = 1;
    return;
  }
  if (!input.existsSync()) {
    stderr.writeln('Brak pliku wejściowego: ${input.path}');
    exitCode = 1;
    return;
  }

  final passphrase = passFile.readAsStringSync().trim();
  if (passphrase.isEmpty) {
    stderr.writeln('Plik z hasłem jest pusty.');
    exitCode = 1;
    return;
  }

  final content = input.readAsStringSync();
  try {
    final result = mode == 'enc'
        ? await CryptoService.encrypt(content, passphrase)
        : await CryptoService.decrypt(content, passphrase);
    output.writeAsStringSync(result);
    final action = mode == 'enc' ? 'Zaszyfrowano' : 'Odszyfrowano';
    stdout.writeln('$action: ${input.path} -> ${output.path} (${result.length} B)');
  } on CryptoException catch (e) {
    stderr.writeln('Błąd krypto: ${e.message}');
    exitCode = 1;
  }
}
