import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nalam_ai/services/remote_ai_service.dart';

void main() {
  test('reports online only for a healthy Nalam server', () async {
    final service = RemoteAiService(
      baseUri: Uri.parse('https://nalam.test'),
      client: MockClient((request) async {
        expect(request.url.path, '/health');
        return http.Response(jsonEncode({'status': 'healthy'}), 200);
      }),
    );

    expect(await service.isAvailable(), isTrue);
    service.dispose();
  });

  test('sends the prompt to chat and extracts the server response', () async {
    final service = RemoteAiService(
      baseUri: Uri.parse('https://nalam.test'),
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/chat');
        expect(
          request.headers['content-type'],
          startsWith('multipart/form-data'),
        );
        expect(request.body, contains('Assess fever and cough'));
        return http.Response(
          jsonEncode({'success': true, 'response': '{"urgency":"low"}'}),
          200,
        );
      }),
    );

    final result = await service.generateResponse('Assess fever and cough');
    expect(result, '{"urgency":"low"}');
    service.dispose();
  });

  test('treats request failures as offline', () async {
    final service = RemoteAiService(
      baseUri: Uri.parse('https://nalam.test'),
      client: MockClient((_) async => throw Exception('network unavailable')),
    );

    expect(await service.isAvailable(), isFalse);
    service.dispose();
  });

  test('accepts a physical-device LAN server address', () {
    final service = RemoteAiService(
      baseUri: Uri.parse('http://10.0.2.2:8000'),
      client: MockClient((_) async => http.Response('', 500)),
    );

    service.setBaseUrl('http://192.168.1.25:8000');
    expect(service.baseUri, Uri.parse('http://192.168.1.25:8000'));
    expect(
      () => service.setBaseUrl('192.168.1.25:8000'),
      throwsFormatException,
    );
    service.dispose();
  });
}
