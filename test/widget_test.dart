import 'package:flutter_test/flutter_test.dart';
import 'package:plants/main.dart';

void main() {
  testWidgets('Crop Guard smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CropGuardApp());

    // Verify Crop Guard title is present
    expect(find.text('Crop Guard'), findsOneWidget);
  });
}
