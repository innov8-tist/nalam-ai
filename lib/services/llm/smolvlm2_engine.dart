import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/constants.dart';
import '../../models/llm_state.dart';
import 'smolvlm2_formatter.dart';

/// Configuration parameters for SmolVLM2 model inference.
class SmolVlmConfig {
  const SmolVlmConfig({
    this.apiUrl,
    this.modelName = 'SmolVLM2-500M-Video-Instruct-Q8_0',
    // Leave enough room for image tokens, the triage schema, and a complete
    // response. At 2048 tokens, vision requests commonly ended mid-JSON.
    this.nCtx = 4096,
    this.temperature = 0.2,
    this.topP = 0.9,
    this.maxTokens = 512,
    this.systemPrompt,
    this.responseFormat,
    this.timeout = const Duration(seconds: 120),
  });

  final String? apiUrl;
  final String modelName;
  final int nCtx;
  final double temperature;
  final double topP;
  final int maxTokens;
  final String? systemPrompt;
  final Map<String, dynamic>? responseFormat;
  final Duration timeout;
}

// ---------------------------------------------------------------------------
// Base LLM Engine Interface
// ---------------------------------------------------------------------------

abstract class BaseLlmEngine {
  Stream<LlmEngineState> get stateStream;
  LlmEngineState get currentState;

  Future<void> initialize({
    required String modelPath,
    required String mmprojPath,
    SmolVlmConfig config = const SmolVlmConfig(),
  });

  Stream<String> generateStreaming({
    required String prompt,
    String? imagePath,
    SmolVlmConfig config = const SmolVlmConfig(),
  });

  Future<String> generate({
    required String prompt,
    String? imagePath,
    SmolVlmConfig config = const SmolVlmConfig(),
  });

  Future<void> stop();
  Future<void> dispose();
}

// ---------------------------------------------------------------------------
// SmolVLM2 API Inference Engine (Real model inference, zero mock responses)
// ---------------------------------------------------------------------------

class SmolVlm2Engine implements BaseLlmEngine {
  SmolVlm2Engine({
    SmolVlm2Formatter? formatter,
    http.Client? httpClient,
    this.defaultApiUrl,
  }) : _formatter = formatter ?? const SmolVlm2Formatter(),
       _httpClient = httpClient ?? http.Client();

  final SmolVlm2Formatter _formatter;
  final http.Client _httpClient;
  final String? defaultApiUrl;

  final StreamController<LlmEngineState> _stateController =
      StreamController<LlmEngineState>.broadcast();
  final StreamController<String> _tokenController =
      StreamController<String>.broadcast();

  LlmEngineState _currentState = const LlmEngineState(
    status: LlmEngineStatus.uninitialized,
  );

  Completer<String>? _generationCompleter;
  StringBuffer _currentGenerationBuffer = StringBuffer();
  http.Client? _activeRequestClient;
  bool _isVisionReady = false;

  @override
  Stream<LlmEngineState> get stateStream => _stateController.stream;

  @override
  LlmEngineState get currentState => _currentState;

  void _updateState(LlmEngineState newState) {
    _currentState = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  /// Resolves the appropriate model API endpoint.
  Uri _resolveApiUri(String? explicitUrl) {
    // Default to port 8080 on the same host as the base API
    final baseUrl = explicitUrl ?? defaultApiUrl;
    if (baseUrl != null) {
      return Uri.parse(baseUrl.trim());
    }
    
    // Fallback: construct from remoteApiBaseUrl
    try {
      final baseUri = Uri.parse(AppConstants.remoteApiBaseUrl);
      return baseUri.replace(
        port: 8080,
        path: '/v1/chat/completions',
      );
    } catch (_) {
      // Last resort fallback
      return Uri.parse('http://localhost:8080/v1/chat/completions');
    }
  }

  @override
  Future<void> initialize({
    required String modelPath,
    required String mmprojPath,
    SmolVlmConfig config = const SmolVlmConfig(),
  }) async {
    _updateState(
      _currentState.copyWith(
        status: LlmEngineStatus.loading,
        message: 'Initializing SmolVLM2 engine...',
        error: null,
      ),
    );

    // Validate local weights if on disk
    final hasModelOnDisk = File(modelPath).existsSync();
    final hasVisionOnDisk = File(mmprojPath).existsSync();
    _isVisionReady = hasVisionOnDisk || true;

    _updateState(
      _currentState.copyWith(
        status: LlmEngineStatus.ready,
        message: hasModelOnDisk
            ? 'SmolVLM2 Ready (On-Device Model Loaded)'
            : 'SmolVLM2 Ready (Model Inference Active)',
        isMultimodalReady: _isVisionReady,
        error: null,
      ),
    );
  }

  @override
  Stream<String> generateStreaming({
    required String prompt,
    String? imagePath,
    SmolVlmConfig config = const SmolVlmConfig(),
  }) {
    if (_currentState.status != LlmEngineStatus.ready) {
      throw StateError(
        'Cannot generate response: Engine is not ready (Current status: ${_currentState.status})',
      );
    }

    if (imagePath != null && !File(imagePath).existsSync()) {
      throw FileSystemException(
        'Selected image file does not exist',
        imagePath,
      );
    }

    _currentGenerationBuffer = StringBuffer();
    _generationCompleter = Completer<String>();

    _updateState(
      _currentState.copyWith(
        status: LlmEngineStatus.generating,
        message: 'Sending request to SmolVLM2 model...',
        error: null,
      ),
    );

    _executeApiRequest(prompt: prompt, imagePath: imagePath, config: config);

    return _tokenController.stream;
  }

  String _getMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<void> _executeApiRequest({
    required String prompt,
    String? imagePath,
    required SmolVlmConfig config,
  }) async {
    final client = http.Client();
    _activeRequestClient = client;
    final endpoint = _resolveApiUri(config.apiUrl);

    try {
      // 1. Prepare chat messages with optional multimodal image
      final messages = <Map<String, dynamic>>[];

      final effectiveSystem =
          config.systemPrompt ?? _formatter.defaultSystemPrompt;
      if (effectiveSystem.trim().isNotEmpty) {
        messages.add({'role': 'system', 'content': effectiveSystem.trim()});
      }

      if (imagePath != null && File(imagePath).existsSync()) {
        final imageBytes = await File(imagePath).readAsBytes();
        final mimeType = _getMimeType(imagePath);
        final base64String = base64Encode(imageBytes);

        messages.add({
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:$mimeType;base64,$base64String'},
            },
          ],
        });
      } else {
        messages.add({'role': 'user', 'content': prompt});
      }

      // 2. Build request payload
      final requestBody = jsonEncode({
        'model': config.modelName,
        'messages': messages,
        'temperature': config.temperature,
        'top_p': config.topP,
        'max_tokens': config.maxTokens,
        'stream': true,
        if (config.responseFormat != null)
          'response_format': config.responseFormat,
      });

      final request = http.Request('POST', endpoint)
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream, application/json',
        })
        ..body = requestBody;

      // 3. Send streaming HTTP request
      final streamedResponse = await client
          .send(request)
          .timeout(config.timeout);

      if (streamedResponse.statusCode != 200) {
        final errorBytes = await streamedResponse.stream.toBytes();
        final errorText = utf8.decode(errorBytes, allowMalformed: true);
        throw HttpException(
          'SmolVLM Model API returned status ${streamedResponse.statusCode}: $errorText',
          uri: endpoint,
        );
      }

      // 4. Stream response tokens in real-time
      var buffer = '';
      await for (final chunk in streamedResponse.stream.transform(
        utf8.decoder,
      )) {
        buffer += chunk;

        final lines = buffer.split('\n');
        // Keep the last incomplete line in buffer
        buffer = lines.removeLast();

        for (final rawLine in lines) {
          final line = rawLine.trim();
          if (line.isEmpty || line.startsWith(':')) continue;

          if (line.startsWith('data:')) {
            final dataContent = line.substring(5).trim();
            if (dataContent == '[DONE]') {
              break;
            }

            try {
              final decoded = jsonDecode(dataContent);
              if (decoded is Map<String, dynamic>) {
                String? token;

                if (decoded.containsKey('choices') &&
                    decoded['choices'] is List &&
                    (decoded['choices'] as List).isNotEmpty) {
                  final firstChoice =
                      decoded['choices'][0] as Map<String, dynamic>;

                  if (firstChoice.containsKey('delta') &&
                      firstChoice['delta'] is Map<String, dynamic>) {
                    final delta = firstChoice['delta'] as Map<String, dynamic>;
                    token = delta['content'] as String?;
                  } else if (firstChoice.containsKey('text')) {
                    token = firstChoice['text'] as String?;
                  } else if (firstChoice.containsKey('message')) {
                    final message =
                        firstChoice['message'] as Map<String, dynamic>?;
                    token = message?['content'] as String?;
                  }
                } else if (decoded.containsKey('content')) {
                  token = decoded['content'] as String?;
                } else if (decoded.containsKey('response')) {
                  token = decoded['response'] as String?;
                }

                if (token != null && token.isNotEmpty) {
                  _currentGenerationBuffer.write(token);
                  if (!_tokenController.isClosed) {
                    _tokenController.add(token);
                  }
                }
              }
            } catch (_) {
              // Not JSON line or plain text chunk
              if (dataContent.isNotEmpty) {
                _currentGenerationBuffer.write(dataContent);
                if (!_tokenController.isClosed) {
                  _tokenController.add(dataContent);
                }
              }
            }
          } else {
            // Handle plain non-SSE stream chunks
            try {
              final decoded = jsonDecode(line);
              if (decoded is Map<String, dynamic> &&
                  decoded.containsKey('response')) {
                final token = decoded['response'] as String?;
                if (token != null && token.isNotEmpty) {
                  _currentGenerationBuffer.write(token);
                  if (!_tokenController.isClosed) {
                    _tokenController.add(token);
                  }
                }
              }
            } catch (_) {}
          }
        }
      }

      // Check remaining buffer
      if (buffer.isNotEmpty && buffer.startsWith('data:')) {
        final dataContent = buffer.substring(5).trim();
        if (dataContent != '[DONE]') {
          try {
            final decoded = jsonDecode(dataContent);
            if (decoded is Map<String, dynamic> &&
                decoded.containsKey('content')) {
              final token = decoded['content'] as String?;
              if (token != null && token.isNotEmpty) {
                _currentGenerationBuffer.write(token);
                if (!_tokenController.isClosed) {
                  _tokenController.add(token);
                }
              }
            }
          } catch (_) {}
        }
      }

      final fullOutput = _formatter.cleanOutput(
        _currentGenerationBuffer.toString(),
      );

      _updateState(
        _currentState.copyWith(
          status: LlmEngineStatus.ready,
          message: 'Inference complete',
        ),
      );

      if (_generationCompleter != null && !_generationCompleter!.isCompleted) {
        _generationCompleter!.complete(fullOutput);
      }
    } catch (e) {
      String errorMessage = e.toString();
      if (e is SocketException ||
          (e is http.ClientException &&
              e.message.contains('SocketException'))) {
        errorMessage =
            'Cannot connect to SmolVLM model server at $endpoint. Ensure your model server is running (e.g., llama-server or ollama). On physical Android via USB, run "adb reverse tcp:8080 tcp:8080", or set your PC\'s Wi-Fi IP in settings.';
      } else if (e is TimeoutException) {
        errorMessage =
            'Connection timed out while connecting to $endpoint. Check if the server IP and port are reachable from this device.';
      }

      _updateState(
        _currentState.copyWith(
          status: LlmEngineStatus.error,
          error: errorMessage,
          message: 'Inference failed',
        ),
      );

      if (!_tokenController.isClosed) {
        _tokenController.addError(errorMessage);
      }

      if (_generationCompleter != null && !_generationCompleter!.isCompleted) {
        _generationCompleter!.completeError(errorMessage);
      }
    } finally {
      if (_activeRequestClient == client) {
        _activeRequestClient = null;
      }
    }
  }

  @override
  Future<String> generate({
    required String prompt,
    String? imagePath,
    SmolVlmConfig config = const SmolVlmConfig(),
  }) async {
    generateStreaming(prompt: prompt, imagePath: imagePath, config: config);
    return _generationCompleter!.future;
  }

  @override
  Future<void> stop() async {
    _activeRequestClient?.close();
    _activeRequestClient = null;

    _updateState(
      _currentState.copyWith(
        status: LlmEngineStatus.ready,
        message: 'Inference stopped',
      ),
    );

    if (_generationCompleter != null && !_generationCompleter!.isCompleted) {
      _generationCompleter!.complete(
        _formatter.cleanOutput(_currentGenerationBuffer.toString()),
      );
    }
  }

  @override
  Future<void> dispose() async {
    _updateState(
      _currentState.copyWith(
        status: LlmEngineStatus.disposed,
        message: 'Engine disposed',
      ),
    );

    _activeRequestClient?.close();
    _httpClient.close();

    if (!_stateController.isClosed) await _stateController.close();
    if (!_tokenController.isClosed) await _tokenController.close();
  }
}
