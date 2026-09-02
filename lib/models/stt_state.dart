enum SttEngineStatus {
  uninitialized,
  checking,
  downloading,
  ready,
  recording,
  transcribing,
  error,
  disposed,
}

class SttEngineState {
  const SttEngineState({
    required this.status,
    this.message,
    this.downloadProgress,
    this.error,
  });

  final SttEngineStatus status;
  final String? message;
  final double? downloadProgress;
  final String? error;

  bool get isReady => status == SttEngineStatus.ready;
  bool get isRecording => status == SttEngineStatus.recording;
  bool get isTranscribing => status == SttEngineStatus.transcribing;
  bool get isBusy =>
      status == SttEngineStatus.checking ||
      status == SttEngineStatus.downloading ||
      status == SttEngineStatus.recording ||
      status == SttEngineStatus.transcribing;
  bool get hasError => status == SttEngineStatus.error;

  SttEngineState copyWith({
    SttEngineStatus? status,
    String? message,
    double? downloadProgress,
    String? error,
  }) {
    return SttEngineState(
      status: status ?? this.status,
      message: message ?? this.message,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      error: error ?? this.error,
    );
  }

  @override
  String toString() =>
      'SttEngineState(status: $status, message: $message, progress: $downloadProgress, error: $error)';
}
