import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

class ServerTestDialog extends StatefulWidget {
  final String? primaryUrl;
  final String? fallbackUrl;

  const ServerTestDialog({
    super.key,
    this.primaryUrl,
    this.fallbackUrl,
  });

  @override
  State<ServerTestDialog> createState() => _ServerTestDialogState();
}

class _ServerTestDialogState extends State<ServerTestDialog> {
  String _aiServiceStatus = 'Testing...';
  String _fallbackServiceStatus = 'Testing...';
  String _smolVlmStatus = 'Testing...';
  bool _isTestingAi = true;
  bool _isTestingFallback = false;
  bool _isTestingVlm = true;

  @override
  void initState() {
    super.initState();
    _isTestingFallback = widget.fallbackUrl != null && widget.fallbackUrl!.isNotEmpty;
    _testConnections();
  }

  Future<void> _testConnections() async {
    final primaryBase = widget.primaryUrl ?? 'http://10.128.184.195:8000';
    final primaryHealth = primaryBase.endsWith('/') ? '${primaryBase}health' : '$primaryBase/health';

    // Test AI Service
    _testEndpoint(
      primaryHealth,
      onResult: (success, message) {
        if (mounted) {
          setState(() {
            _aiServiceStatus = message;
            _isTestingAi = false;
          });
        }
      },
    );

    // Test Fallback AI Service
    if (widget.fallbackUrl != null && widget.fallbackUrl!.isNotEmpty) {
      final fallbackBase = widget.fallbackUrl!;
      final fallbackHealth = fallbackBase.endsWith('/') ? '${fallbackBase}health' : '$fallbackBase/health';
      _testEndpoint(
        fallbackHealth,
        onResult: (success, message) {
          if (mounted) {
            setState(() {
              _fallbackServiceStatus = message;
              _isTestingFallback = false;
            });
          }
        },
      );
    }

    // Determine SmolVLM2 URL (port 8080) from primary
    String smolVlmUrl = 'http://10.128.184.195:8080/health';
    try {
      final uri = Uri.parse(primaryBase);
      if (uri.hasPort && uri.port == 8000) {
        smolVlmUrl = uri.replace(port: 8080).resolve('health').toString();
      } else {
        smolVlmUrl = uri.resolve('health').toString().replaceAll(':${uri.port}', ':8080');
      }
    } catch (_) {}

    // Test SmolVLM2 API
    _testEndpoint(
      smolVlmUrl,
      onResult: (success, message) {
        if (mounted) {
          setState(() {
            _smolVlmStatus = message;
            _isTestingVlm = false;
          });
        }
      },
    );
  }

  Future<void> _testEndpoint(
    String url, {
    required Function(bool success, String message) onResult,
  }) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        onResult(true, '✅ Connected (${response.statusCode})');
      } else {
        onResult(false, '⚠️ Server responded with ${response.statusCode}');
      }
    } on TimeoutException {
      onResult(false, '❌ Timeout - Server not responding');
    } catch (e) {
      onResult(false, '❌ Error: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFallback = widget.fallbackUrl != null && widget.fallbackUrl!.isNotEmpty;
    return AlertDialog(
      title: const Text('Server Connection Test'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configured Primary Server:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              widget.primaryUrl ?? 'http://10.128.184.195:8000',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (hasFallback) ...[
              const SizedBox(height: 8),
              const Text(
                'Configured Fallback Server:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                widget.fallbackUrl!,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 16),
            _buildTestResult(
              'AI Service (Primary)',
              _aiServiceStatus,
              _isTestingAi,
            ),
            if (hasFallback) ...[
              const SizedBox(height: 12),
              _buildTestResult(
                'AI Service (Fallback)',
                _fallbackServiceStatus,
                _isTestingFallback,
              ),
            ],
            const SizedBox(height: 12),
            _buildTestResult(
              'SmolVLM2 API (port 8080)',
              _smolVlmStatus,
              _isTestingVlm,
            ),
            const SizedBox(height: 16),
            if (!_isTestingAi && !_isTestingVlm && !_isTestingFallback)
              const Text(
                'Troubleshooting:\n'
                '• Check laptop server is running\n'
                '• Verify server binds to 0.0.0.0\n'
                '• Both devices on same WiFi (or fallback setup configured)\n'
                '• Firewall allows ports 8000, 8080',
                style: TextStyle(fontSize: 12),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _isTestingAi = true;
              _isTestingFallback = hasFallback;
              _isTestingVlm = true;
              _aiServiceStatus = 'Testing...';
              _fallbackServiceStatus = 'Testing...';
              _smolVlmStatus = 'Testing...';
            });
            _testConnections();
          },
          child: const Text('Retry'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildTestResult(String label, String status, bool testing) {
    return Row(
      children: [
        if (testing)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(
            status.startsWith('✅')
                ? Icons.check_circle
                : Icons.error,
            size: 16,
            color: status.startsWith('✅')
                ? Colors.green
                : Colors.red,
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  color: status.startsWith('✅')
                      ? Colors.green
                      : Colors.red,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
