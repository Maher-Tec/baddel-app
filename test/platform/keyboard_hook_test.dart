import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:badeli/platform/keyboard_hook.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses native keyboard events', () {
    final event = KeyboardHookEvent.fromMap({
      'virtualKey': 0x41,
      'scanCode': 30,
      'flags': 0,
      'time': 123,
      'foregroundWindow': 456,
      'processName': 'notepad.exe',
    });

    expect(event.virtualKey, 0x41);
    expect(event.scanCode, 30);
    expect(event.time, 123);
    expect(event.processName, 'notepad.exe');
    expect(TargetApps.contains(event.processName), isTrue);
  });

  test('forwards key events from the method channel', () async {
    const channel = MethodChannel('test/keyboard_hook');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
    final client = KeyboardHookClient(channel: channel);
    final events = <KeyboardHookEvent>[];
    final subscription = client.events.listen(events.add);

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('keyEvent', {
              'virtualKey': 0x41,
              'scanCode': 30,
              'flags': 0,
              'time': 123,
              'foregroundWindow': 456,
              'processName': 'code.exe',
            }),
          ),
          (_) {},
        );

    await Future<void>.delayed(Duration.zero);
    expect(events, hasLength(1));
    expect(events.single.virtualKey, 0x41);

    await subscription.cancel();
    await client.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('shows warning popup and forwards its actions', () async {
    const channel = MethodChannel('test/warning_popup');
    MethodCall? receivedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          receivedCall = call;
          if (call.method == 'showWarningPopup') return true;
          return null;
        });
    final client = KeyboardHookClient(channel: channel);
    final actions = <String>[];
    final subscription = client.warningActions.listen(actions.add);

    final shown = await client.showWarningPopup(
      title: 'Baddel! 😂 Rak tiktib bel chinwa ya bro',
      suggestion: 'hello this',
      confidence: 85,
    );
    expect(shown, isTrue);
    expect(receivedCall?.method, 'showWarningPopup');
    expect(receivedCall?.arguments, {
      'title': 'Baddel! 😂 Rak tiktib bel chinwa ya bro',
      'suggestion': 'hello this',
      'confidence': 85,
    });

    await client.captureDetectedText(
      expected: 'اثممخ فاهس',
      selectionUnits: 9,
      trailingUnits: 1,
    );
    expect(receivedCall?.method, 'captureDetectedText');
    expect(receivedCall?.arguments, {
      'expected': 'اثممخ فاهس',
      'selectionUnits': 9,
      'trailingUnits': 1,
    });

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('warningAction', 'pause'),
          ),
          (_) {},
        );
    await Future<void>.delayed(Duration.zero);
    expect(actions, ['pause']);

    await subscription.cancel();
    await client.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}
