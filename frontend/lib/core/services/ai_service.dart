import 'package:http/http.dart' as http;
class AIService {

  Future<http.Response> sendGoal(String baseUrl, String message, String token) async {
    return await http.post(
      Uri.parse('$baseUrl/goal/test_user?goal=${Uri.encodeComponent(message)}'),
      headers: {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'X-HomeGenie-Token': token,
      },
    ).timeout(const Duration(seconds: 60));
  }

  Future<http.Response> transcribeAudio(String baseUrl, String token, List<int> audioBytes, String filename) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/voice/transcribe'));
    if (token.isNotEmpty) request.headers['X-HomeGenie-Token'] = token;
    request.files.add(http.MultipartFile.fromBytes('file', audioBytes, filename: filename));
    
    final streamed = await request.send().timeout(const Duration(seconds: 90));
    return await http.Response.fromStream(streamed);
  }
}
