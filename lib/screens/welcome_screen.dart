import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE9F7F4), Color(0xFFCAE8D5), Color(0xFF77B873)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 94,
                  height: 94,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.health_and_safety,
                    size: 62,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'NalamEdge',
                  style: TextStyle(
                    fontSize: 30,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'AI-Powered Healthcare Guidance\nfor Every Community',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.45),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: _LanguageButton(
                        label: 'English',
                        selected: app.languageCode == 'en',
                        onTap: () => app.setLanguage('en'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _LanguageButton(
                        label: 'മലയാളം',
                        selected: app.languageCode == 'ml',
                        onTap: () => app.setLanguage('ml'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                PrimaryButton(label: 'Get Started', onPressed: app.start),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      backgroundColor: selected ? Colors.white : Colors.white54,
      foregroundColor: AppColors.primaryDark,
      minimumSize: const Size.fromHeight(50),
      side: BorderSide(
        color: selected ? AppColors.primary : Colors.transparent,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}
