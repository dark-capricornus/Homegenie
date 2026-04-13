import 'package:http/http.dart' as http;
class InsightsService {

  Future<List<http.Response>> fetchInsightsData(String baseUrl, {String token = ''}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'X-HomeGenie-Token': token,
    };
    return await Future.wait([
      http.get(Uri.parse('$baseUrl/learning/insights/default_user'), headers: headers).timeout(const Duration(seconds: 10)),
      http.get(Uri.parse('$baseUrl/learning/suggestions/default_user'), headers: headers).timeout(const Duration(seconds: 10)),
      http.get(Uri.parse('$baseUrl/learning/analytics/default_user'), headers: headers).timeout(const Duration(seconds: 10)),
    ]);
  }
}
