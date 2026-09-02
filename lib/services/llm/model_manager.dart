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
  });

  final String? customModelDirectory;
  final String modelFileName;
  final String mmprojFileName;
  final String modelDownloadUrl;
  final String mmprojDownloadUrl;

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
      if (Platform.isAndroid) {
        final supportDir = await getApplicationSupportDirectory();
        basePath = supportDir.path;
      } else {
        final appDocDir = await getApplicationDocumentsDirectory();
        basePath = appDocDir.path;
      }
    } catch (_) {
      try {
        final appDocDir = await getApplicationDocumentsDirectory();
        basePath = appDocDir.path;
      } catch (_) {
        if (Platform.isAndroid) {
          final candidate = Directory('/data/data/com.example.nalam_ai/app_flutter');
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
    return file.existsSync() && file.lengthSync() > 10 * 1024 * 1024;
  }

  /// Checks if the multimodal projector is present locally on device.
  Future<bool> isMmprojDownloaded() async {
    final path = await getMmprojPath();
    final file = File(path);
    return file.existsSync() && file.lengthSync() > 5 * 1024 * 1024;
  }

  /// Resolves available model file paths.
  Future<ModelFiles> getModelFiles() async {
    final modelPath = await getModelPath();
    final mmprojPath = await getMmprojPath();
    final isVision = File(mmprojPath).existsSync() && File(mmprojPath).lengthSync() > 0;

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
    if (!modelFile.existsSync() || modelFile.lengthSync() < 10 * 1024 * 1024) {
      final modelUrls = [
        modelDownloadUrl,
        AppConstants.smolVlmModelMirrorDownloadUrl,
      ];
      bool ok = false;
      Object? lastError;
      for (final u in modelUrls) {
        try {
          await _downloadFile(
            url: u,
            destinationPath: targetModelPath,
            fileName: modelFileName,
            onProgress: onProgress,
          );
          ok = true;
          break;
        } catch (e) {
          lastError = e;
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
      if (!ok && lastError != null) {
        throw lastError;
      }
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
    if (!mmprojFile.existsSync() || mmprojFile.lengthSync() < 5 * 1024 * 1024) {
      final mmprojUrls = [
        mmprojDownloadUrl,
        AppConstants.smolVlmMmprojMirrorDownloadUrl,
      ];
      for (final u in mmprojUrls) {
        try {
          await _downloadFile(
            url: u,
            destinationPath: targetMmprojPath,
            fileName: mmprojFileName,
            onProgress: onProgress,
          );
          break;
        } catch (_) {
          // Projector download failure should not block text-only mode
        }
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

    int resumeOffset = 0;
    if (tempFile.existsSync()) {
      resumeOffset = tempFile.lengthSync();
    }

    final client = http.Client();
    IOSink? sink;

    try {
      final request = http.Request('GET', Uri.parse(url));
      request.followRedirects = true;
      request.maxRedirects = 10;
      request.headers['User-Agent'] =
          'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36';

      if (resumeOffset > 0) {
        request.headers['Range'] = 'bytes=$resumeOffset-';
      }

      final response = await client.send(request);

      var receivedBytes = 0;
      if (response.statusCode == 206 && resumeOffset > 0) {
        sink = tempFile.openWrite(mode: FileMode.append);
        receivedBytes = resumeOffset;
      } else if (response.statusCode == 200) {
        if (resumeOffset > 0 && tempFile.existsSync()) {
          tempFile.deleteSync();
        }
        sink = tempFile.openWrite();
      } else if (response.statusCode == 416 && resumeOffset > 0) {
        if (tempFile.existsSync()) tempFile.deleteSync();
        client.close();
        return await _downloadFile(
          url: url,
          destinationPath: destinationPath,
          fileName: fileName,
          onProgress: onProgress,
        );
      } else {
        throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
      }

      final contentLength = response.contentLength ?? 0;
      final totalBytes = response.statusCode == 206
          ? resumeOffset + contentLength
          : (contentLength > 0 ? contentLength : -1);

      var lastProgressUpdate = DateTime.now();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        final now = DateTime.now();
        if (now.difference(lastProgressUpdate).inMilliseconds >= 100 ||
            (totalBytes > 0 && receivedBytes >= totalBytes)) {
          lastProgressUpdate = now;
          final fraction =
              totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
          final receivedMb = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
          final totalMb = totalBytes > 0
              ? '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
              : 'calculating...';

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
      await sink.close();
      sink = null;

      if (File(destinationPath).existsSync()) {
        await File(destinationPath).delete();
      }
      await tempFile.rename(destinationPath);
    } finally {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      client.close();
    }
  }

  void dispose() {}
}
