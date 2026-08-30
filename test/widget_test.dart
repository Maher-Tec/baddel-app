import 'package:flutter_test/flutter_test.dart';

import 'package:badeli/main.dart';

void main() {
  testWidgets('shows the Baddel product screen', (tester) async {
    await tester.pumpWidget(BaddelApp(enableDesktopShell: false));

    expect(find.text('Baddel! Keyboard Language Helper'), findsOneWidget);
    expect(find.text('Start hook'), findsOneWidget);
    expect(find.text('Events received: 0'), findsOneWidget);
    expect(find.text('Personality & Humor'), findsOneWidget);
    expect(find.text('Apps'), findsOneWidget);
  });
}
