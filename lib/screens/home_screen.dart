import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import 'assessment_screen.dart';
import 'monitoring_screen.dart';
import 'profile_screen.dart';
import 'recommended_facility_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeDashboard(onAssess: () => setState(() => index = 1)),
      const AssessmentScreen(),
      const RecommendedFacilityScreen(embedded: true),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        indicatorColor: AppColors.mint,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.primary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.health_and_safety_outlined),
            selectedIcon: Icon(
              Icons.health_and_safety,
              color: AppColors.primary,
            ),
            label: 'Assess',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_hospital_outlined),
            selectedIcon: Icon(Icons.local_hospital, color: AppColors.primary),
            label: 'Care',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({required this.onAssess, super.key});
  final VoidCallback onAssess;
  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final text = TextEditingController();
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.health_and_safety, color: AppColors.primary),
            SizedBox(width: 8),
            Text('NalamEdge'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MonitoringScreen()),
            ),
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const OfflineBadge(),
            const SizedBox(height: 18),
            const Text(
              'നമസ്കാരം 👋',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const Text(
              'How are you feeling today?',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            SectionCard(
              child: Column(
                children: [
                  InkWell(
                    onTap: widget.onAssess,
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      width: 82,
                      height: 82,
                      decoration: const BoxDecoration(
                        color: AppColors.mint,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mic,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Talk to NalamEdge',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const Text(
                    'Tap to speak',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 18),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Or type your symptoms'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: text,
                    decoration: InputDecoration(
                      hintText: 'e.g. I have fever and cough...',
                      suffixIcon: IconButton(
                        onPressed: widget.onAssess,
                        icon: const Icon(
                          Icons.arrow_forward,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Assessments',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MonitoringScreen()),
                  ),
                  child: const Text('View All'),
                ),
              ],
            ),
            ...app.history.take(3).map((entry) {
              final p = severityPresentation(entry.severity);
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: SectionCard(
                  padding: const EdgeInsets.all(13),
                  child: Row(
                    children: [
                      Icon(Icons.medical_information_outlined, color: p.color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.symptoms,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        p.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: p.color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
