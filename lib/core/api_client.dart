import 'dart:convert';
import 'package:http/http.dart' as http;

class YgoApiClient {
  static const _baseUrl = 'https://db.ygoprodeck.com/api/v7/cardinfo.php';

  Future<List<dynamic>> fetchCards(Map<String, String> params) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      String? errorText;
      try {
        final json = jsonDecode(response.body);
        if (json is Map && json['error'] != null) {
          errorText = json['error'].toString();
        }
      } catch (_) {}

      if (response.statusCode == 400 &&
          errorText != null &&
          errorText.toLowerCase().contains('no card matching')) {
        return const <dynamic>[];
      }

      final message = errorText != null
          ? 'API error: ${response.statusCode} - $errorText'
          : 'API error: ${response.statusCode}';

      throw Exception(message);
    }

    final json = jsonDecode(response.body);

    if (json is Map && json.containsKey('error')) {
      final err = json['error']?.toString() ?? 'unknown';
      if (err.toLowerCase().contains('no card matching')) return const <dynamic>[];
      throw Exception('API error: $err');
    }

    return (json['data'] as List<dynamic>?) ?? const <dynamic>[];
  }
}
