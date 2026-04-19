import 'dart:convert';
import 'package:http/http.dart' as http;

class AgoraTokenService {
  AgoraTokenService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // Replace with deployed Firebase Function URL per environment.
  static const String _tokenEndpoint =
      String.fromEnvironment('AGORA_TOKEN_ENDPOINT', defaultValue: '');

  Future<String?> fetchRtcToken({
    required String channelName,
    required String uid,
    required bool videoEnabled,
  }) async {
    if (_tokenEndpoint.isEmpty) {
      return null;
    }

    final res = await _client.post(
      Uri.parse(_tokenEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'channelName': channelName,
        'uid': uid,
        'role': videoEnabled ? 'publisher' : 'subscriber',
        'expireSeconds': 3600,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Token endpoint failed (${res.statusCode})');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return json['token'] as String?;
  }
}
