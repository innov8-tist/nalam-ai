import 'package:flutter_test/flutter_test.dart';
import 'package:nalam_ai/app.dart';

void main() {
  testWidgets('feature buttons update the workspace', (tester) async {
    await tester.pumpWidget(const NalamApp());

    expect(find.text('Medical Triage Workspace'), findsOneWidget);
    expect(find.text('TTS'), findsOneWidget);
    expect(find.text('STT'), findsOneWidget);
    expect(find.text('LLM'), findsOneWidget);
    expect(find.text('MAP'), findsOneWidget);

    await tester.tap(find.text('STT'));
    await tester.pumpAndSettle();

    expect(find.text('STT module selected'), findsOneWidget);
  });
}
