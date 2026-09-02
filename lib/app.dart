import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'state/app_controller.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';

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
