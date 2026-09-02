import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'state/app_controller.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';

class ConnectionStatusBar extends StatelessWidget {
  const ConnectionStatusBar({super.key});

  Future<void> _configureServer(
    BuildContext context,
    AppController controller,
  ) async {
    final primaryInput = TextEditingController(text: controller.serverUrl);
    final fallbackInput = TextEditingController(text: controller.fallbackServerUrl);
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nalam server configuration'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Primary Server (Local Wi-Fi):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Enter your laptop\'s Wi-Fi IP address when both devices are on the same network.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: primaryInput,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Primary address (e.g. http://10.128.184.195:8000)',
                    labelStyle: TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Fallback Server (Internet/ngrok):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Enter a public URL (like ngrok) to use when connected to cellular internet or when local Wi-Fi is unreachable.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: fallbackInput,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Fallback/Internet address (Optional)',
                    labelStyle: TextStyle(fontSize: 12),
                    hintText: 'e.g. https://yourtunnel.ngrok-free.app',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final valid = await controller.setServerUrls(
                  primaryUrl: primaryInput.text,
                  fallbackUrl: fallbackInput.text,
                );
                if (!dialogContext.mounted) return;
                if (!valid && controller.assessmentError != null) {
                  setDialogState(() => error = controller.assessmentError);
                  return;
                }
                Navigator.pop(dialogContext);
              },
              child: const Text('Save & test'),
            ),
          ],
        ),
      ),
    );
    primaryInput.dispose();
    fallbackInput.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final online = controller.isOnline;
    return Material(
      color: online ? const Color(0xFFE7F6EC) : const Color(0xFFFFF3E0),
      child: Builder(
        builder: (builderContext) => InkWell(
          onTap: () => _configureServer(builderContext, controller),
          child: SizedBox(
            height: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  online ? Icons.cloud_done_outlined : Icons.offline_bolt,
                  size: 13,
                  color: online ? AppColors.primary : AppColors.urgent,
                ),
                const SizedBox(width: 5),
                Text(
                  online ? 'Online' : 'Offline Mode',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: online ? AppColors.primaryDark : AppColors.urgent,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.settings_outlined, size: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NalamApp extends StatefulWidget {
  const NalamApp({super.key});
  @override
  State<NalamApp> createState() => _NalamAppState();
}

class _NalamAppState extends State<NalamApp> {
  late final AppController controller;
  @override
  void initState() {
    super.initState();
    controller = AppController()..initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        builder: (context, child) => Column(
          children: [
            const SafeArea(bottom: false, child: ConnectionStatusBar()),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ],
        ),
        home: ListenableBuilder(
          listenable: controller,
          builder: (_, _) => controller.hasSeenWelcome
              ? const HomeScreen()
              : const WelcomeScreen(),
        ),
      ),
    );
  }
}
