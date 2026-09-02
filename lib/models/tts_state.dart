enum TtsEngineStatus {
  uninitialized,
  checking,
  downloading,
  loading,
  ready,
  speaking,
  error,
  disposed,
}

class TtsEngineState {
  const TtsEngineState({
    required this.status,
    this.message,
    this.downloadProgress,
    this.error,
    this.modelDownloaded = false,
  });

  final TtsEngineStatus status;
  final String? message;
  final double? downloadProgress;
  final String? error;
  final bool modelDownloaded;

  bool get isReady => status == TtsEngineStatus.ready;
  bool get isSpeaking => status == TtsEngineStatus.speaking;
  bool get isBusy =>
      status == TtsEngineStatus.downloading ||
      status == TtsEngineStatus.loading ||
      status == TtsEngineStatus.speaking ||
      status == TtsEngineStatus.checking;
  bool get hasError => status == TtsEngineStatus.error;

  TtsEngineState copyWith({
    TtsEngineStatus? status,
    String? message,
    double? downloadProgress,
    String? error,
    bool? modelDownloaded,
  }) {
    return TtsEngineState(
      status: status ?? this.status,
      message: message ?? this.message,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      error: error ?? this.error,
      modelDownloaded: modelDownloaded ?? this.modelDownloaded,
    );
  }

  @override
  String toString() =>
      'TtsEngineState(status: $status, message: $message, progress: $downloadProgress, error: $error, modelDownloaded: $modelDownloaded)';
}
