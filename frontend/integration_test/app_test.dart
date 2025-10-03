// HomeGenie Flutter App Integration Test
// This test verifies the main functionality of the app

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:homegenie_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('HomeGenie App Integration Tests', () {
    testWidgets('App loads and displays main UI elements', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Verify the app title is displayed
      expect(find.text('🏠 HomeGenie Control'), findsOneWidget);

      // Verify the quick actions buttons are present
      expect(find.text('Make it Cozy'), findsOneWidget);
      expect(find.text('Save Energy'), findsOneWidget);

      // Verify device states section
      expect(find.text('📱 Device States'), findsOneWidget);

      // Verify refresh button is present
      expect(find.byTooltip('Refresh'), findsOneWidget);
    });

    testWidgets('Refresh button works', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Tap the refresh button
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pump();

      // App should still be functional after refresh
      expect(find.text('🏠 HomeGenie Control'), findsOneWidget);
    });
  });
}