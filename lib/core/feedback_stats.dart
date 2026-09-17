import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeedbackStats extends ChangeNotifier {
  FeedbackStats._(this._preferences, this._events);

  static const _storageKey = 'feedback_events_v1';
  final SharedPreferences? _preferences;
  final List<_FeedbackEvent> _events;

  static Future<FeedbackStats> load() async {
    final preferences = await SharedPreferences.getInstance();
    final events = <_FeedbackEvent>[];
    for (final raw in preferences.getStringList(_storageKey) ?? <String>[]) {
      try {
        events.add(
          _FeedbackEvent.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        );
      } catch (e) {
        debugPrint('Baddel: skipping corrupt feedback event: $e');
      }
    }
    final stats = FeedbackStats._(preferences, events);
    stats._removeOlderThan(const Duration(days: 90));
    return stats;
  }

  factory FeedbackStats.inMemory() => FeedbackStats._(null, []);

  int get fixesThisWeek => _countSince('fix', const Duration(days: 7));
  int get fixesToday => _countSince('fix', const Duration(days: 1));
  int get dismissalsThisWeek => _countSince('dismiss', const Duration(days: 7));

  String get mostActiveApp {
    final counts = <String, int>{};
    for (final event in _events.where((event) => event.action == 'fix')) {
      counts[event.app] = (counts[event.app] ?? 0) + 1;
    }
    if (counts.isEmpty) return 'No corrections yet';
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// Always returns the baseline threshold, deliberately ignoring [app] and
  /// the recorded fix/dismiss history: this is an invariant, not a stub.
  /// Feedback is useful for diagnostics, but it must never let a user's
  /// dismissals reduce detection sensitivity in an app. Someone dismissing
  /// warnings while learning the product should still receive future real
  /// warnings at full strength — so this never adapts downward, and there is
  /// currently no upward-adaptive behavior either. See warningThresholdFor
  /// lock-in test in feedback_stats_test.dart.
  double warningThresholdFor(String app) => 0.82;

  Future<void> recordFix(String app) => _record('fix', app);
  Future<void> recordDismissal(String app) => _record('dismiss', app);

  int _countSince(String action, Duration duration) {
    final cutoff = DateTime.now().subtract(duration);
    return _events
        .where((event) => event.action == action && event.time.isAfter(cutoff))
        .length;
  }

  Future<void> _record(String action, String app) async {
    _events.add(
      _FeedbackEvent(
        action,
        app.trim().isEmpty ? 'Unknown app' : app,
        DateTime.now(),
      ),
    );
    _removeOlderThan(const Duration(days: 90));
    await _preferences?.setStringList(
      _storageKey,
      _events.map((event) => jsonEncode(event.toJson())).toList(),
    );
    notifyListeners();
  }

  void _removeOlderThan(Duration duration) {
    final cutoff = DateTime.now().subtract(duration);
    _events.removeWhere((event) => event.time.isBefore(cutoff));
  }
}

class _FeedbackEvent {
  const _FeedbackEvent(this.action, this.app, this.time);
  final String action;
  final String app;
  final DateTime time;

  Map<String, dynamic> toJson() => {
    'action': action,
    'app': app,
    'time': time.toIso8601String(),
  };

  factory _FeedbackEvent.fromJson(Map<String, dynamic> json) => _FeedbackEvent(
    json['action'] as String,
    json['app'] as String,
    DateTime.parse(json['time'] as String),
  );
}
