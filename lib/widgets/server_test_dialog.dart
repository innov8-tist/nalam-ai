import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ServerTestDialog extends StatefulWidget {
  const ServerTestDialog({required this.serverUri, super.key});

  final Uri serverUri;

  @override
  State<ServerTestDialog> createState() => _ServerTestDialogState();
}

class _ServerTestDialogState extends State<ServerTestDialog> {
  String _aiServiceStatus = 'Testing...';
  String _smolVlmStatus = 'Testing...';
  bool _isTestingAi = true;
  bool _isTestingVlm = true;

  @override
  void initState() {
    super.initState();
    _testConnections();
  }

  Future<void> _testConnections() async {
    final aiHealthUri = widget.serverUri.replace(
      path: '/health',
      query: null,
      fragment: null,
    );
    final smolVlmHealthUri = widget.serverUri.replace(
      port: 8080,
      path: '/health',
      query: null,
      fragment: null,
    );

    _testEndpoint(
      aiHealthUri,
      onResult: (success, message) {
        if (mounted) {
          setState(() {
            _aiServiceStatus = message;
            _isTestingAi = false;
          });
        }
      },
    );

    _testEndpoint(
      smolVlmHealthUri,
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
    Uri url, {
    required Function(bool success, String message) onResult,
  }) async {
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));

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
    return AlertDialog(
      title: const Text('Server Connection Test'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Testing connection to:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SelectableText(widget.serverUri.toString()),
          const SizedBox(height: 16),
          _buildTestResult(
            'AI Service (port ${widget.serverUri.port})',
            _aiServiceStatus,
            _isTestingAi,
          ),
          const SizedBox(height: 12),
          _buildTestResult(
            'SmolVLM2 API (port 8080)',
            _smolVlmStatus,
            _isTestingVlm,
          ),
          const SizedBox(height: 16),
          if (!_isTestingAi && !_isTestingVlm)
            const Text(
              'Troubleshooting:\n'
              '• Check laptop server is running\n'
              '• Verify server binds to 0.0.0.0\n'
              '• Both devices on same WiFi\n'
              '• Firewall allows ports 8000, 8080',
              style: TextStyle(fontSize: 12),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _isTestingAi = true;
              _isTestingVlm = true;
              _aiServiceStatus = 'Testing...';
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
            status.startsWith('✅') ? Icons.check_circle : Icons.error,
            size: 16,
            color: status.startsWith('✅') ? Colors.green : Colors.red,
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  color: status.startsWith('✅') ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
