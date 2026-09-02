import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import 'language_screen.dart';
import 'monitoring_screen.dart';
import 'tts_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 31,
                    backgroundColor: AppColors.mint,
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ramesh K.',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Local profile • No sign-in required',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Settings',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            SectionCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _Setting(
                    icon: Icons.language,
                    title: 'Language',
                    trailing: app.languageCode == 'ml' ? 'മലയാളം' : 'English',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LanguageScreen()),
                    ),
                  ),
                  _Setting(
                    icon: Icons.mic_none,
                    title: 'Voice & Speech',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TtsScreen()),
                    ),
                  ),
                  const _Setting(
                    icon: Icons.offline_pin,
                    title: 'Offline Data',
                  ),
                  _Setting(
                    icon: Icons.monitor_heart_outlined,
                    title: 'My Monitoring',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MonitoringScreen(),
                      ),
                    ),
                  ),
                  const _Setting(
                    icon: Icons.accessibility_new,
                    title: 'Accessibility',
                  ),
                  const _Setting(
                    icon: Icons.info_outline,
                    title: 'About NalamEdge',
                  ),
                  const _Setting(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Setting extends StatelessWidget {
  const _Setting({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    onTap:
        onTap ??
        () => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title is not available in this prototype.')),
        ),
    leading: Icon(icon),
    title: Text(title),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (trailing != null)
          Text(trailing!, style: const TextStyle(color: AppColors.muted)),
        const Icon(Icons.chevron_right),
      ],
    ),
  );
}
