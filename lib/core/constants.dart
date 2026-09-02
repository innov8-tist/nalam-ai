abstract final class AppConstants {
  static const String appName = 'Nalam AI';
  static const String workspaceTitle = 'Medical Triage Workspace';

  // SmolVLM2 On-Device Model Defaults
  static const String smolVlmModelDir = 'models/smolvlm2';
  static const String smolVlmModelFileName = 'SmolVLM2-500M-Video-Instruct-Q8_0.gguf';
  static const String smolVlmMmprojFileName = 'mmproj-SmolVLM2-500M-Video-Instruct-Q8_0.gguf';

  // Direct HuggingFace Model Weights Repositories (SmolVLM2)
  static const String smolVlmModelDownloadUrl =
      'https://huggingface.co/ggml-org/SmolVLM2-500M-Video-Instruct-GGUF/resolve/main/SmolVLM2-500M-Video-Instruct-Q8_0.gguf';
  static const String smolVlmMmprojDownloadUrl =
      'https://huggingface.co/ggml-org/SmolVLM2-500M-Video-Instruct-GGUF/resolve/main/mmproj-SmolVLM2-500M-Video-Instruct-Q8_0.gguf';

  // SmolVLM2 Model Server / API Endpoint
  static const String smolVlmDefaultApiUrl = 'http://127.0.0.1:8080/v1/chat/completions';
  static const String smolVlmAndroidEmulatorApiUrl = 'http://10.0.2.2:8080/v1/chat/completions';

  // ChatML & SmolVLM2 template tokens
  static const String imStartToken = '<|im_start|>';
  static const String imEndToken = '<|im_end|>';
  static const String imageToken = '<image>';
}
