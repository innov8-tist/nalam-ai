enum SttEngineStatus { ready, recording, transcribing, downloading, error }

class SttEngineState {
  const SttEngineState({
    required this.status,
    required this.message,
    this.error,
  });

  final SttEngineStatus status;
  final String message;
  final String? error;

  bool get isRecording => status == SttEngineStatus.recording;
  bool get isTranscribing => status == SttEngineStatus.transcribing;
  bool get isBusy => isRecording || isTranscribing;
  bool get hasError => status == SttEngineStatus.error;
}
