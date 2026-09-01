import 'dart:convert';
import 'dart:io';

class UpdateInfo {
  const UpdateInfo({required this.version, required this.url});

  final String version;
  final String url;
}

class UpdateChecker {
  const UpdateChecker({this.currentVersion = '1.1.0'});

  static const manifestUrl =
      'https://raw.githubusercontent.com/Maher-Tec/baddel-app/master/version.json';
  static const releaseUrl = 'https://github.com/Maher-Tec/baddel-app/releases';

  final String currentVersion;

  Future<UpdateInfo?> check() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(manifestUrl)).timeout(
        const Duration(seconds: 4),
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(const Duration(seconds: 4));
      if (response.statusCode != HttpStatus.ok) return null;
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      if (data is! Map<String, dynamic>) return null;
      final version = data['version'];
      if (version is! String || !isNewer(version, currentVersion)) return null;
      final url = data['url'] is String ? data['url'] as String : releaseUrl;
      return UpdateInfo(version: version, url: url);
    } catch (_) {
      // Update checks must never affect startup or normal offline use.
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static bool isNewer(String candidate, String current) {
    List<int> parts(String value) => value
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .take(3)
        .toList();
    final next = parts(candidate);
    final installed = parts(current);
    while (next.length < 3) {
      next.add(0);
    }
    while (installed.length < 3) {
      installed.add(0);
    }
    for (var index = 0; index < 3; index++) {
      if (next[index] != installed[index]) return next[index] > installed[index];
    }
    return false;
  }
}
