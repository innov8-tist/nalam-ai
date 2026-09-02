abstract final class AppConstants {
  static const String appName = 'NalamEdge';
  static const String workspaceTitle = 'Medical Triage Workspace';

  /// Override for deployed builds with
  /// `--dart-define=NALAM_API_BASE_URL=https://your-server.example`.
  static const String remoteApiBaseUrl = String.fromEnvironment(
    'NALAM_API_BASE_URL',
  );

  // Piper TTS Models
  static const String piperModelsDir = 'models/piper';
  static const String piperEnglishModel = 'en_US-libritts-high';
  static const String piperMalayalamModel = 'ml_IN-google-high';

  // Piper TTS Model Download URLs (from Piper releases)
  static const String piperEnglishModelUrl =
      'https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/libritts/high/en_US-libritts-high.onnx';
  static const String piperEnglishModelJsonUrl =
      'https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/libritts/high/en_US-libritts-high.onnx.json';
  static const String piperMalayalamModelUrl =
      'https://huggingface.co/rhasspy/piper-voices/resolve/main/ml/ml_IN/google/high/ml_IN-google-high.onnx';
  static const String piperMalayalamModelJsonUrl =
      'https://huggingface.co/rhasspy/piper-voices/resolve/main/ml/ml_IN/google/high/ml_IN-google-high.onnx.json';


  // SmolVLM2 On-Device Model Defaults
  static const String smolVlmModelDir = 'models/smolvlm2';
  static const String smolVlmModelFileName =
      'SmolVLM2-500M-Video-Instruct-Q8_0.gguf';
  static const String smolVlmMmprojFileName =
      'mmproj-SmolVLM2-500M-Video-Instruct-Q8_0.gguf';

  // Direct HuggingFace Model Weights Repositories (SmolVLM2)
  static const String smolVlmModelDownloadUrl =
      'https://huggingface.co/ggml-org/SmolVLM2-500M-Video-Instruct-GGUF/resolve/main/SmolVLM2-500M-Video-Instruct-Q8_0.gguf';
  static const String smolVlmModelMirrorDownloadUrl =
      'https://hf-mirror.com/ggml-org/SmolVLM2-500M-Video-Instruct-GGUF/resolve/main/SmolVLM2-500M-Video-Instruct-Q8_0.gguf';
  static const String smolVlmMmprojDownloadUrl =
      'https://huggingface.co/ggml-org/SmolVLM2-500M-Video-Instruct-GGUF/resolve/main/mmproj-SmolVLM2-500M-Video-Instruct-Q8_0.gguf';
  static const String smolVlmMmprojMirrorDownloadUrl =
      'https://hf-mirror.com/ggml-org/SmolVLM2-500M-Video-Instruct-GGUF/resolve/main/mmproj-SmolVLM2-500M-Video-Instruct-Q8_0.gguf';

  // SmolVLM2 Model Server / API Endpoint
  static const String smolVlmDefaultApiUrl =
      'http://127.0.0.1:8080/v1/chat/completions';
  static const String smolVlmAndroidEmulatorApiUrl =
      'http://10.0.2.2:8080/v1/chat/completions';

  // STT Model Server / API Endpoint
  static const String sttDefaultApiUrl = 'http://127.0.0.1:8080/v1/audio/transcriptions';
  static const String sttAndroidEmulatorApiUrl = 'http://10.0.2.2:8080/v1/audio/transcriptions';

  // ChatML & SmolVLM2 template tokens
  static const String imStartToken = '<|im_start|>';
  static const String imEndToken = '<|im_end|>';
  static const String imageToken = '<image>';

  // Whisper Speech-to-Text Defaults
  static const String whisperModelDir = 'models/whisper';
  static const String whisperModelFileName = 'ggml-base.bin';
  static const String whisperModelDownloadUrl =
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin';
  static const String whisperModelMirrorDownloadUrl =
      'https://hf-mirror.com/ggerganov/whisper.cpp/resolve/main/ggml-base.bin';
}
