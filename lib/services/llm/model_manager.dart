import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';

class ModelFiles {
  const ModelFiles({
    required this.modelPath,
    required this.mmprojPath,
    required this.isVisionAvailable,
  });

  final String modelPath;
  final String mmprojPath;
  final bool isVisionAvailable;

  bool get isModelAvailable => File(modelPath).existsSync();
}

typedef ModelDownloadProgressCallback = void Function({
  required String fileName,
  required int bytesReceived,
  required int totalBytes,
  required double progressFraction,
  required String message,
});

class ModelManager {
  ModelManager({
    this.customModelDirectory,
    this.modelFileName = AppConstants.smolVlmModelFileName,
    this.mmprojFileName = AppConstants.smolVlmMmprojFileName,
    this.modelDownloadUrl = AppConstants.smolVlmModelDownloadUrl,
    this.mmprojDownloadUrl = AppConstants.smolVlmMmprojDownloadUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String? customModelDirectory;
  final String modelFileName;
  final String mmprojFileName;
  final String modelDownloadUrl;
  final String mmprojDownloadUrl;
  final http.Client _httpClient;

  /// Resolves the storage directory for model files with fallback support.
  Future<Directory> getModelDirectory() async {
    if (customModelDirectory != null) {
      final dir = Directory(customModelDirectory!);
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
      return dir;
    }

    String basePath;
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      basePath = appDocDir.path;
    } catch (_) {
      // Fallback if path_provider plugin has not been compiled into native build yet
      if (Platform.isAndroid) {
        final candidate = Directory(
          '/data/data/com.example.nalam_ai/app_flutter',
        );
        if (candidate.existsSync()) {
          basePath = candidate.path;
        } else {
          basePath = Directory.systemTemp.path;
        }
      } else if (Platform.isLinux || Platform.isMacOS) {
        final home = Platform.environment['HOME'] ?? '.';
        basePath = '$home/.local/share/nalam_ai';
      } else {
        basePath = Directory.systemTemp.path;
      }
    }

    final modelDir = Directory('$basePath/${AppConstants.smolVlmModelDir}');
    if (!modelDir.existsSync()) {
      await modelDir.create(recursive: true);
    }
    return modelDir;
  }

  /// Resolves the full path to the primary language model file.
  Future<String> getModelPath() async {
    final dir = await getModelDirectory();
    return '${dir.path}/$modelFileName';
  }

  /// Resolves the full path to the multimodal projector file.
  Future<String> getMmprojPath() async {
    final dir = await getModelDirectory();
    return '${dir.path}/$mmprojFileName';
  }

  /// Checks if the primary model file is present locally on device.
  Future<bool> isModelDownloaded() async {
    final path = await getModelPath();
    final file = File(path);
    return file.existsSync() && file.lengthSync() > 0;
  }

  /// Checks if the multimodal projector is present locally on device.
  Future<bool> isMmprojDownloaded() async {
    final path = await getMmprojPath();
    final file = File(path);
    return file.existsSync() && file.lengthSync() > 0;
  }

  /// Resolves available model file paths.
  Future<ModelFiles> getModelFiles() async {
    final modelPath = await getModelPath();
    final mmprojPath = await getMmprojPath();
    final isVision =
        File(mmprojPath).existsSync() && File(mmprojPath).lengthSync() > 0;

    return ModelFiles(
      modelPath: modelPath,
      mmprojPath: mmprojPath,
      isVisionAvailable: isVision,
    );
  }

  /// Ensures both model weights and mmproj projector are downloaded to local storage.
  /// If files already exist on device, zero network calls are performed.
  Future<ModelFiles> downloadModelIfNeeded({
    ModelDownloadProgressCallback? onProgress,
  }) async {
    final dir = await getModelDirectory();
    final targetModelPath = '${dir.path}/$modelFileName';
    final targetMmprojPath = '${dir.path}/$mmprojFileName';

    // 1. Download primary language model weights if not present
    final modelFile = File(targetModelPath);
    if (!modelFile.existsSync() || modelFile.lengthSync() == 0) {
      await _downloadFile(
        url: modelDownloadUrl,
        destinationPath: targetModelPath,
        fileName: modelFileName,
        onProgress: onProgress,
      );
    } else {
      onProgress?.call(
        fileName: modelFileName,
        bytesReceived: modelFile.lengthSync(),
        totalBytes: modelFile.lengthSync(),
        progressFraction: 1.0,
        message: 'SmolVLM2 language model found on device',
      );
    }

    // 2. Download multimodal vision projector if not present
    final mmprojFile = File(targetMmprojPath);
    if (!mmprojFile.existsSync() || mmprojFile.lengthSync() == 0) {
      try {
        await _downloadFile(
          url: mmprojDownloadUrl,
          destinationPath: targetMmprojPath,
          fileName: mmprojFileName,
          onProgress: onProgress,
        );
      } catch (e) {
        // Projector download failure should not block text-only mode
      }
    } else {
      onProgress?.call(
        fileName: mmprojFileName,
        bytesReceived: mmprojFile.lengthSync(),
        totalBytes: mmprojFile.lengthSync(),
        progressFraction: 1.0,
        message: 'SmolVLM2 vision projector found on device',
      );
    }

    final hasVision = mmprojFile.existsSync() && mmprojFile.lengthSync() > 0;

    return ModelFiles(
      modelPath: targetModelPath,
      mmprojPath: targetMmprojPath,
      isVisionAvailable: hasVision,
    );
  }

  Future<void> _downloadFile({
    required String url,
    required String destinationPath,
    required String fileName,
    ModelDownloadProgressCallback? onProgress,
  }) async {
    final tempPath = '$destinationPath.tmp';
    final tempFile = File(tempPath);
    if (tempFile.existsSync()) {
      await tempFile.delete();
    }

    var currentUri = Uri.parse(url);
    http.StreamedResponse? response;

    // Follow redirects manually to ensure proper CDN stream handling
    for (var hop = 0; hop < 5; hop++) {
      final request = http.Request('GET', currentUri);
      request.followRedirects = false;
      final res = await _httpClient.send(request);

      if (res.statusCode >= 300 &&
          res.statusCode < 400 &&
          res.headers.containsKey('location')) {
        final location = res.headers['location']!;
        currentUri = Uri.parse(location);
        continue;
      }

      response = res;
      break;
    }

    if (response == null ||
        response.statusCode < 200 ||
        response.statusCode >= 300) {
      final status = response?.statusCode ?? 0;
      throw HttpException(
        'Failed to download $fileName: HTTP status $status from $currentUri',
        uri: currentUri,
      );
    }

    final totalBytes = response.contentLength ?? -1;
    var receivedBytes = 0;
    var lastProgressUpdate = DateTime.now();

    final sink = tempFile.openWrite();
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        final now = DateTime.now();
        // Update at least every 100ms or on completion to keep UI smooth
        if (now.difference(lastProgressUpdate).inMilliseconds >= 100 ||
            (totalBytes > 0 && receivedBytes >= totalBytes)) {
          lastProgressUpdate = now;
          final fraction = totalBytes > 0
              ? (receivedBytes / totalBytes).clamp(0.0, 1.0)
              : 0.0;
          final receivedMb = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
          final totalMb = totalBytes > 0
              ? '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
              : 'calculating size...';

          onProgress?.call(
            fileName: fileName,
            bytesReceived: receivedBytes,
            totalBytes: totalBytes,
            progressFraction: fraction,
            message:
                'Downloading $fileName: $receivedMb MB / $totalMb (${(fraction * 100).toStringAsFixed(0)}%)',
          );
        }
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    // Atomically move tmp file to destination
    if (File(destinationPath).existsSync()) {
      await File(destinationPath).delete();
    }
    await tempFile.rename(destinationPath);
  }

  /// Closes the HTTP client if needed.
  void dispose() {
    _httpClient.close();
  }
}
