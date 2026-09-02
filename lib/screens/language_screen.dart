import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Language')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Choose your preferred language',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            _Option(
              title: 'English',
              subtitle: 'Continue in English',
              selected: app.languageCode == 'en',
              onTap: () => app.setLanguage('en'),
            ),
            const SizedBox(height: 10),
            _Option(
              title: 'മലയാളം',
              subtitle: 'മലയാളത്തിൽ തുടരുക',
              selected: app.languageCode == 'ml',
              onTap: () => app.setLanguage('ml'),
            ),
            const SizedBox(height: 30),
            const Text(
              'You can change language anytime from settings.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final String title, subtitle;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.mint : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
    ),
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.all(12),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? AppColors.primary : AppColors.muted,
      ),
    ),
  );
}
