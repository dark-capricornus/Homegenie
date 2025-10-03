import 'package:flutter_test/flutter_test.dart';
import 'package:homegenie_app/main.dart';

void main() {
  testWidgets('HomeGenie app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const HomeGenieApp());

    // Verify that the app title is present
    expect(find.text('🏠 HomeGenie Control'), findsOneWidget);
    
    // Verify that the quick actions buttons are present
    expect(find.text('Make it Cozy'), findsOneWidget);
    expect(find.text('Save Energy'), findsOneWidget);
    
    // Verify device states section
    expect(find.text('📱 Device States'), findsOneWidget);
  });
}