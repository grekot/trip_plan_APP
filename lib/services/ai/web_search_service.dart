import 'package:http/http.dart' as http;

/// Wynik wyszukiwania internetowego.
class WebSearchResult {
  final String title;
  final String url;
  final String snippet;
  const WebSearchResult({required this.title, required this.url, required this.snippet});

  Map<String, dynamic> toJson() => {'title': title, 'url': url, 'snippet': snippet};
}

/// Wyszukiwanie internetowe dla dostawców bez natywnego web search
/// (DeepSeek, Gemini przez warstwę OpenAI-compat). DuckDuckGo HTML —
/// bez klucza API; parsowanie regexem jest proste, ale wystarczające
/// do podania modelowi tytułów/URL-i/snippetów.
class WebSearchService {
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36';
  static const _timeout = Duration(seconds: 20);

  /// Zwraca do [maxResults] wyników z DuckDuckGo.
  static Future<List<WebSearchResult>> search(String query,
      {int maxResults = 5}) async {
    final uri = Uri.parse(
        'https://html.duckduckgo.com/html/?q=${Uri.encodeQueryComponent(query)}');
    final resp = await http
        .get(uri, headers: {'User-Agent': _ua, 'Accept-Language': 'pl,en'})
        .timeout(_timeout);
    if (resp.statusCode != 200) {
      throw Exception('DuckDuckGo zwrócił ${resp.statusCode}');
    }
    final html = resp.body;

    // Linki wyników: <a ... class="result__a" href="//duckduckgo.com/l/?uddg=<URL>&...">Tytuł</a>
    final linkRe = RegExp(
        r'class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>',
        dotAll: true);
    final snippetRe = RegExp(
        r'class="result__snippet"[^>]*>(.*?)</a>',
        dotAll: true);

    final links = linkRe.allMatches(html).toList();
    final snippets = snippetRe.allMatches(html).toList();

    final results = <WebSearchResult>[];
    for (var i = 0; i < links.length && results.length < maxResults; i++) {
      final rawHref = links[i].group(1)!;
      final url = _resolveDdgUrl(rawHref);
      if (url == null) continue;
      final title = _stripHtml(links[i].group(2)!);
      final snippet =
          i < snippets.length ? _stripHtml(snippets[i].group(1)!) : '';
      if (title.isEmpty) continue;
      results.add(WebSearchResult(title: title, url: url, snippet: snippet));
    }
    return results;
  }

  /// Pobiera stronę i zwraca oczyszczony tekst (bez HTML), przycięty do
  /// [maxChars] znaków — tyle wystarczy modelowi, a chroni budżet tokenów.
  static Future<String> fetchUrl(String url, {int maxChars = 8000}) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      throw Exception('Nieprawidłowy adres URL (wymagany http/https).');
    }
    final resp = await http
        .get(uri, headers: {'User-Agent': _ua, 'Accept-Language': 'pl,en'})
        .timeout(_timeout);
    if (resp.statusCode != 200) {
      throw Exception('Strona zwróciła ${resp.statusCode}');
    }
    final contentType = resp.headers['content-type'] ?? '';
    if (contentType.isNotEmpty &&
        !contentType.contains('text') &&
        !contentType.contains('json') &&
        !contentType.contains('xml')) {
      throw Exception('Nieobsługiwany typ treści: $contentType');
    }
    var text = resp.body;
    // Usuń skrypty/style, potem wszystkie tagi.
    text = text.replaceAll(
        RegExp(r'<(script|style|noscript)[^>]*>.*?</\1>',
            dotAll: true, caseSensitive: false),
        ' ');
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
    text = _decodeEntities(text);
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r'\s*\n\s*(\n\s*)+'), '\n');
    text = text.trim();
    if (text.length > maxChars) {
      text = '${text.substring(0, maxChars)}\n[…treść przycięta]';
    }
    return text;
  }

  /// Linki DDG są przekierowaniami `//duckduckgo.com/l/?uddg=<enc>&rut=…`.
  static String? _resolveDdgUrl(String href) {
    final full = href.startsWith('//') ? 'https:$href' : href;
    final uri = Uri.tryParse(full);
    if (uri == null) return null;
    final uddg = uri.queryParameters['uddg'];
    if (uddg != null && uddg.isNotEmpty) return uddg;
    if (uri.scheme == 'http' || uri.scheme == 'https') return full;
    return null;
  }

  static String _stripHtml(String s) =>
      _decodeEntities(s.replaceAll(RegExp(r'<[^>]+>'), '')).trim();

  static String _decodeEntities(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#x27;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ');
}
