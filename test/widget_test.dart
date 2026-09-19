// Unit tests for DailyHub's rule-based Smart Capture parser.
//
// The default `flutter create` counter test was removed: it referenced a
// `MyApp` class this project never had. A widget test of the real app would
// need Firebase initialised, which doesn't work in a plain unit test, so the
// useful thing to test here is the parser — it's pure Dart with no plugins.

import 'package:flutter_test/flutter_test.dart';

import 'package:dailyhub/core/quick_parse.dart';

void main() {
  group('QuickParse.splitItems', () {
    test('splits on commas, newlines and "and"', () {
      final items = QuickParse.splitItems('Buy charger, call Rahul\npay bill');
      expect(items.length, 3);
      expect(items[0], 'Buy charger');
      expect(items[2], 'pay bill');
    });

    test('ignores empty fragments', () {
      expect(QuickParse.splitItems('a,,  ,b').length, 2);
    });
  });

  group('QuickParse.parseOne', () {
    test('classifies an action verb as a task', () {
      expect(QuickParse.parseOne('Buy charger').kind, CaptureKind.task);
    });

    test('classifies explicit reminder wording as a reminder', () {
      final item = QuickParse.parseOne('remind me to call mom');
      expect(item.kind, CaptureKind.reminder);
    });

    test('classifies money + spending word as an expense', () {
      final item = QuickParse.parseOne('paid 500 rs for lunch');
      expect(item.kind, CaptureKind.expense);
      expect(item.amount, 500);
    });

    test('falls back to a note when nothing matches', () {
      expect(QuickParse.parseOne('random thought').kind, CaptureKind.note);
    });

    test('extracts a rupee amount written with a symbol', () {
      expect(QuickParse.parseOne('spent ₹250 on food').amount, 250);
    });
  });

  group('QuickParse date handling', () {
    test('understands tomorrow', () {
      final item = QuickParse.parseOne('book train tomorrow');
      expect(item.when, isNotNull);
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(item.when!.day, tomorrow.day);
    });

    test('understands a 12-hour time', () {
      final item = QuickParse.parseOne('meeting tomorrow 5pm');
      expect(item.when, isNotNull);
      expect(item.when!.hour, 17);
    });

    test('leaves plain text without a date', () {
      expect(QuickParse.parseOne('buy milk').when, isNull);
    });
  });
}
