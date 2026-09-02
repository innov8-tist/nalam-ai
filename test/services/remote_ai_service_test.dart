import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nalam_ai/core/constants.dart';
import 'package:nalam_ai/services/remote_ai_service.dart';

void main() {
  test('uses the single configured server URL by default', () {
    final service = RemoteAiService(
      client: MockClient((_) async => http.Response('', 500)),
    );

    expect(service.baseUri, AppConstants.serverUri);
    expect(
      AppConstants.smolVlmApiUrl,
      'http://10.0.2.2:8080/v1/chat/completions',
    );
    service.dispose();
  });

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

  test('uploads recorded audio and returns the Sarvam transcript', () async {
    final audio = File(
      '${Directory.systemTemp.path}/nalam_remote_ai_service_test.wav',
    );
    await audio.writeAsBytes([82, 73, 70, 70, 1, 2, 3, 4]);
    final service = RemoteAiService(
      baseUri: Uri.parse('https://nalam.test'),
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/transcribe');
        expect(
          request.headers['content-type'],
          startsWith('multipart/form-data'),
        );
        expect(request.body, contains('name="language_code"'));
        expect(request.body, contains('ml-IN'));
        expect(request.body, contains('name="audio"'));
        return http.Response(
          jsonEncode({'success': true, 'transcript': 'എനിക്ക് പനി ഉണ്ട്'}),
          200,
        );
      }),
    );

    try {
      expect(
        await service.transcribeAudio(audio.path, languageCode: 'ml-IN'),
        'എനിക്ക് പനി ഉണ്ട്',
      );
    } finally {
      service.dispose();
      if (await audio.exists()) await audio.delete();
    }
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
