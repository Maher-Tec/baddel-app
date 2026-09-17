import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:badeli/main.dart';
import 'package:badeli/screens/onboarding_page.dart';
import 'package:badeli/settings/app_settings.dart';

void main() {
  testWidgets('shows the Baddel product screen', (tester) async {
    // Set a large screen size for widget test
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(BaddelApp(enableDesktopShell: false));

    expect(find.text('Baddel!'), findsOneWidget);
    expect(find.text('Start protection'), findsOneWidget);
    expect(find.text('Try Baddel'), findsOneWidget);
    expect(find.text('Protected apps'), findsOneWidget);
  });

  testWidgets('guides a new user through onboarding', (tester) async {
    final settings = AppSettings.inMemory(onboardingComplete: false);
    await tester.pumpWidget(
      MaterialApp(home: PrivacyOnboardingPage(settings: settings)),
    );

    expect(find.text('Your typing, on the right language.'), findsOneWidget);
    await tester.tap(find.text('Start setup'));
    await tester.pump();
    expect(find.text('Which keyboard do you use?'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Where should Baddel help?'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('You are ready to go.'), findsOneWidget);
  });
}
