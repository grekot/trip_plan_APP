import 'dart:io';
import 'package:qr/qr.dart';

/// Generuje kod QR (jako HTML z inline SVG) kodujący podany tekst — np. hasło
/// do planów. Wszystko lokalnie: hasło NIE trafia do żadnego zewnętrznego
/// serwisu. Otwórz wynikowy .html w przeglądarce i zeskanuj telefonem.
///
/// Użycie:
///   dart run tool/make_qr.dart <plik-z-tekstem|tekst> <wyjscie.html>
void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('Użycie: dart run tool/make_qr.dart <plik-z-tekstem|tekst> <wyjscie.html>');
    exitCode = 2;
    return;
  }
  final f = File(args[0]);
  final data = f.existsSync() ? f.readAsStringSync().trim() : args[0];
  if (data.isEmpty) {
    stderr.writeln('Pusty tekst do zakodowania.');
    exitCode = 1;
    return;
  }

  final qr = QrImage(QrCode.fromData(
    data: data,
    errorCorrectLevel: QrErrorCorrectLevel.M,
  ));
  final n = qr.moduleCount;
  const cell = 10;
  const quiet = 4; // margines (quiet zone) w modułach
  final dim = (n + quiet * 2) * cell;

  final rects = StringBuffer();
  for (var r = 0; r < n; r++) {
    for (var c = 0; c < n; c++) {
      if (qr.isDark(r, c)) {
        final x = (c + quiet) * cell;
        final y = (r + quiet) * cell;
        rects.write('<rect x="$x" y="$y" width="$cell" height="$cell"/>');
      }
    }
  }

  final html = '''<!DOCTYPE html>
<html lang="pl"><head><meta charset="UTF-8"><title>Kod QR — hasło planów</title>
<style>
  body { font-family: "Segoe UI", Arial, sans-serif; text-align: center; padding: 24px; color: #1a2027; }
  h1 { color: #1E6B52; font-size: 20px; }
  .qr { margin: 16px auto; width: ${dim}px; max-width: 90vw; }
  .pass { font-family: Consolas, monospace; font-size: 18px; background: #f0f3f5; display: inline-block; padding: 8px 14px; border-radius: 8px; margin-top: 8px; user-select: all; }
  .note { color: #6b7480; font-size: 13px; max-width: 480px; margin: 16px auto; }
</style></head><body>
  <h1>Hasło planów — kod QR</h1>
  <div class="qr">
    <svg viewBox="0 0 $dim $dim" xmlns="http://www.w3.org/2000/svg" width="$dim" height="$dim" shape-rendering="crispEdges">
      <rect width="$dim" height="$dim" fill="#ffffff"/>
      <g fill="#000000">$rects</g>
    </svg>
  </div>
  <div class="pass">$data</div>
  <p class="note">W aplikacji: Biblioteka planów → Hasło → „Skanuj kod QR" i skieruj telefon na ten kod.
  Trzymaj ten plik prywatnie — zawiera hasło deszyfrujące plany.</p>
</body></html>
''';

  File(args[1]).writeAsStringSync(html);
  stdout.writeln('QR zapisany: ${args[1]}  (moduły: $n, rozmiar: ${dim}px)');
}
