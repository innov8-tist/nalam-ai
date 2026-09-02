import '../../core/constants.dart';

/// Formatter for constructing SmolVLM2 ChatML prompt templates.
class SmolVlm2Formatter {
  const SmolVlm2Formatter({
    this.defaultSystemPrompt = 'You are a helpful on-device assistant. Provide direct, concise, and clear answers.',
  });

  final String defaultSystemPrompt;

  /// Stop sequences used by SmolVLM2 to terminate generation.
  static const List<String> stopTokens = [
    '<|im_end|>',
    '<|end_of_text|>',
    '<end_of_utterance>',
    '<|im_start|>',
  ];

  /// Builds the complete prompt template for SmolVLM2 inference.
  String formatPrompt({
    required String userPrompt,
    String? systemPrompt,
    bool hasImage = false,
  }) {
    final effectiveSystem = systemPrompt ?? defaultSystemPrompt;
    final buffer = StringBuffer();

    if (effectiveSystem.trim().isNotEmpty) {
      buffer.write(
        '${AppConstants.imStartToken}system\n${effectiveSystem.trim()}${AppConstants.imEndToken}\n',
      );
    }

    buffer.write('${AppConstants.imStartToken}user\n');
    if (hasImage) {
      buffer.write('${AppConstants.imageToken}\n');
    }
    buffer.write('${userPrompt.trim()}${AppConstants.imEndToken}\n');
    buffer.write('${AppConstants.imStartToken}assistant\n');

    return buffer.toString();
  }

  /// Cleans and trims raw token output by removing trailing stop tokens.
  String cleanOutput(String rawText) {
    var cleaned = rawText;
    for (final token in stopTokens) {
      if (cleaned.endsWith(token)) {
        cleaned = cleaned.substring(0, cleaned.length - token.length);
      }
    }
    return cleaned.trim();
  }
}
