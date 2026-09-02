import 'package:flutter_test/flutter_test.dart';
import 'package:nalam_ai/app.dart';

void main() {
  testWidgets('welcome opens the NalamEdge home shell', (tester) async {
    await tester.pumpWidget(const NalamApp());
    await tester.pump();
    expect(find.text('NalamEdge'), findsOneWidget);
    expect(
      find.text('AI-Powered Healthcare Guidance\nfor Every Community'),
      findsOneWidget,
    );
    expect(find.text('Offline Mode'), findsOneWidget);
    await tester.tap(find.text('Get Started'));
    await tester.pump();
    expect(find.text('Talk to NalamEdge'), findsOneWidget);
    expect(find.text('Assess'), findsOneWidget);
    expect(find.text('Care'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
