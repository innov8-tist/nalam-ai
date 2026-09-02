import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../core/constants.dart';

/// Client for the more capable Nalam AI server in `logic/main.py`.
class RemoteAiService {
  RemoteAiService({http.Client? client, Uri? baseUri})
    : _client = client ?? http.Client(),
      _ownsClient = client == null,
      _baseUri = baseUri ?? _defaultBaseUri;

  final http.Client _client;
  final bool _ownsClient;
  Uri _baseUri;
  Uri get baseUri => _baseUri;

  void setBaseUrl(String value) {
    final parsed = Uri.tryParse(value.trim());
    if (parsed == null ||
        (parsed.scheme != 'http' && parsed.scheme != 'https') ||
        parsed.host.isEmpty) {
      throw const FormatException(
        'Enter a complete address such as http://192.168.1.25:8000',
      );
    }
    _baseUri = parsed;
  }

  static Uri get _defaultBaseUri {
    return AppConstants.serverUri;
  }

  Uri _endpoint(String path) {
    final root = baseUri.toString().endsWith('/')
        ? baseUri
        : Uri.parse('${baseUri.toString()}/');
    return root.resolve(path);
  }

  Future<bool> isAvailable({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      final response = await _client.get(_endpoint('health')).timeout(timeout);
      if (response.statusCode != 200) return false;
      final payload = jsonDecode(response.body);
      return payload is Map && payload['status'] == 'healthy';
    } catch (_) {
      return false;
    }
  }

  Future<String> generateResponse(
    String prompt, {
    String? imagePath,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final request = http.MultipartRequest('POST', _endpoint('chat'))
      ..fields['text_prompt'] = prompt;
    if (imagePath != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imagePath,
          contentType: _imageContentType(imagePath),
        ),
      );
    }

    final streamed = await _client.send(request).timeout(timeout);
    final response = await http.Response.fromStream(streamed);
    Map<String, dynamic>? payload;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
    } catch (_) {}

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = payload?['detail']?.toString();
      throw RemoteAiException(
        detail?.isNotEmpty == true
            ? detail!
            : 'Server returned HTTP ${response.statusCode}.',
      );
    }
    final result = payload?['response'];
    if (result is! String || result.trim().isEmpty) {
      throw const RemoteAiException('Server returned an empty response.');
    }
    return result.trim();
  }

  Future<String> transcribeAudio(
    String audioPath, {
    String languageCode = 'unknown',
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final request = http.MultipartRequest('POST', _endpoint('transcribe'))
      ..fields['language_code'] = languageCode
      ..files.add(
        await http.MultipartFile.fromPath(
          'audio',
          audioPath,
          contentType: MediaType('audio', 'wav'),
        ),
      );

    final streamed = await _client.send(request).timeout(timeout);
    final response = await http.Response.fromStream(streamed);
    Map<String, dynamic>? payload;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
    } catch (_) {}

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = payload?['detail']?.toString();
      throw RemoteAiException(
        detail?.isNotEmpty == true
            ? detail!
            : 'Transcription server returned HTTP ${response.statusCode}.',
      );
    }

    final transcript = payload?['transcript'];
    if (transcript is! String || transcript.trim().isEmpty) {
      throw const RemoteAiException(
        'No speech was recognized. Please try again and speak clearly.',
      );
    }
    return transcript.trim();
  }

  MediaType _imageContentType(String path) {
    final extension = path.toLowerCase().split('.').last;
    return switch (extension) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      'gif' => MediaType('image', 'gif'),
      _ => MediaType('image', 'jpeg'),
    };
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}

class RemoteAiException implements Exception {
  const RemoteAiException(this.message);
  final String message;

  @override
  String toString() => message;
}
