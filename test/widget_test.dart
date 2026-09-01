import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:badeli/main.dart' hide PrivacyOnboardingPage;
import 'package:badeli/screens/onboarding_page.dart';
import 'package:badeli/settings/app_settings.dart';

void main() {
  testWidgets('shows the Baddel product screen', (tester) async {
    // Set a large screen size for widget test
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(BaddelApp(enableDesktopShell: false));

    expect(find.text('Baddel! Keyboard Language Helper'), findsOneWidget);
    expect(find.text('Start hook'), findsOneWidget);
    expect(find.text('Personality & Humor'), findsOneWidget);
    expect(find.text('Apps'), findsOneWidget);

    // Switch to Developer mode to verify dev metrics
    await tester.tap(find.text('Developer'));
    await tester.pumpAndSettle();

    expect(find.text('Events received: 0'), findsOneWidget);
  });

  testWidgets('guides a new user through onboarding', (tester) async {
    final settings = AppSettings.inMemory(onboardingComplete: false);
    await tester.pumpWidget(MaterialApp(home: PrivacyOnboardingPage(settings: settings)));

    expect(find.text('Welcome to Baddel!'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Choose your apps'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Choose your style'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('You are ready!'), findsOneWidget);
  });
}
