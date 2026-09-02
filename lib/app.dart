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
    final input = TextEditingController(text: controller.serverUrl);
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nalam server'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This is the single server address used by health checks, '
                'assessment, and voice transcription. Build default: '
                '${AppConstants.serverUrl}',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: input,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Server address',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final valid = await controller.setRemoteServerUrl(input.text);
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
    input.dispose();
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
