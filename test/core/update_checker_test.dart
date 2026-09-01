import 'package:flutter_test/flutter_test.dart';
import 'package:badeli/core/update_checker.dart';

void main() {
  test('compares semantic versions and accepts v prefixes', () {
    expect(UpdateChecker.isNewer('1.2.0', '1.1.0'), isTrue);
    expect(UpdateChecker.isNewer('v1.1.0', '1.1.0'), isFalse);
    expect(UpdateChecker.isNewer('1.0.9', '1.1.0'), isFalse);
  });
}
