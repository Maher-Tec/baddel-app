import 'package:flutter_test/flutter_test.dart';
import 'package:badeli/core/feedback_stats.dart';

void main() {
  test('records fixes and dismissals without storing text', () async {
    final stats = FeedbackStats.inMemory();

    await stats.recordFix('chrome.exe');
    await stats.recordFix('chrome.exe');
    await stats.recordDismissal('code.exe');

    expect(stats.fixesThisWeek, 2);
    expect(stats.dismissalsThisWeek, 1);
    expect(stats.mostActiveApp, 'chrome.exe');
  });

  test('raises the threshold for an app with repeated dismissals', () async {
    final stats = FeedbackStats.inMemory();

    await stats.recordDismissal('chrome.exe');
    await stats.recordDismissal('chrome.exe');
    await stats.recordDismissal('chrome.exe');

    expect(stats.warningThresholdFor('chrome.exe'), 0.94);
    expect(stats.warningThresholdFor('code.exe'), 0.82);
  });
}
