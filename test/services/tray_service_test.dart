import 'package:flutter_test/flutter_test.dart';

import 'package:badeli/services/tray_service.dart';

void main() {
  test('constructs the tray service', () {
    expect(const TrayService(), isA<TrayService>());
  });
}
