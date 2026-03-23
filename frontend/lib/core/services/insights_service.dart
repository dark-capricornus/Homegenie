import 'package:http/http.dart' as http;
class InsightsService {

  Future<List<http.Response>> fetchInsightsData(String baseUrl) async {
    return await Future.wait([
      http.get(Uri.parse('$baseUrl/learning/insights/default_user')).timeout(const Duration(seconds: 10)),
      http.get(Uri.parse('$baseUrl/learning/suggestions/default_user')).timeout(const Duration(seconds: 10)),
      http.get(Uri.parse('$baseUrl/learning/analytics/default_user')).timeout(const Duration(seconds: 10)),
    ]);
  }
}
