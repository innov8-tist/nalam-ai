enum LlmEngineStatus {
  uninitialized,
  checking,
  downloading,
  loading,
  ready,
  generating,
  error,
  disposed,
}

class LlmEngineState {
  const LlmEngineState({
    required this.status,
    this.message,
    this.downloadProgress,
    this.error,
    this.isMultimodalReady = false,
  });

  final LlmEngineStatus status;
  final String? message;
  final double? downloadProgress;
  final String? error;
  final bool isMultimodalReady;

  bool get isReady => status == LlmEngineStatus.ready;
  bool get isGenerating => status == LlmEngineStatus.generating;
  bool get isBusy =>
      status == LlmEngineStatus.loading ||
      status == LlmEngineStatus.downloading ||
      status == LlmEngineStatus.generating ||
      status == LlmEngineStatus.checking;
  bool get hasError => status == LlmEngineStatus.error;

  LlmEngineState copyWith({
    LlmEngineStatus? status,
    String? message,
    double? downloadProgress,
    String? error,
    bool? isMultimodalReady,
  }) {
    return LlmEngineState(
      status: status ?? this.status,
      message: message ?? this.message,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      error: error ?? this.error,
      isMultimodalReady: isMultimodalReady ?? this.isMultimodalReady,
    );
  }

  @override
  String toString() =>
      'LlmEngineState(status: $status, message: $message, progress: $downloadProgress, error: $error, isMultimodalReady: $isMultimodalReady)';
}
