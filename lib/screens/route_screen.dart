import 'package:flutter/material.dart';

import '../models/assessment_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

class RouteScreen extends StatelessWidget {
  const RouteScreen({required this.facility, super.key});
  final Facility facility;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Route to Hospital')),
    body: Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: const Color(0xFFE7EEE8),
            child: CustomPaint(painter: _MapPlaceholderPainter()),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 18,
          child: SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  facility.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                Text(
                  '${facility.distanceKm} km  •  ~${facility.etaMinutes} min',
                ),
                Wrap(
                  spacing: 5,
                  children: facility.capabilities
                      .take(3)
                      .map((e) => CapabilityBadge(label: e))
                      .toList(),
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: 'Start Navigation',
                  icon: Icons.navigation,
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Offline map routing is not connected yet.',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _MapPlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final roads = Paint()
      ..color = Colors.white
      ..strokeWidth = 7;
    for (double y = 50; y < s.height; y += 85) {
      c.drawLine(Offset(0, y), Offset(s.width, y + 35), roads);
    }
    final route = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final p = Path()
      ..moveTo(s.width * .25, s.height * .72)
      ..lineTo(s.width * .38, s.height * .58)
      ..lineTo(s.width * .34, s.height * .4)
      ..lineTo(s.width * .7, s.height * .22);
    c.drawPath(p, route);
    c.drawCircle(
      Offset(s.width * .25, s.height * .72),
      11,
      Paint()..color = Colors.blue,
    );
    c.drawCircle(
      Offset(s.width * .7, s.height * .22),
      12,
      Paint()..color = AppColors.danger,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
