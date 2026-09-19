/// Rule-based parsing for "Capture Now, Organize Later".
///
/// No AI API is involved — this is deterministic keyword + pattern matching,
/// which means it runs offline, costs nothing, and never leaks user text to a
/// third party. It splits a brain-dump into separate items and guesses what
/// each one should become (task / reminder / expense / note).
///
/// It is intentionally conservative: when it isn't reasonably sure, it falls
/// back to a note and lets the user decide. The UI always shows the guess for
/// confirmation before anything is saved.
library;

enum CaptureKind { task, reminder, expense, note }

class ParsedItem {
  final String text;
  final CaptureKind kind;
  final DateTime? when;
  final double? amount;

  ParsedItem({
    required this.text,
    required this.kind,
    this.when,
    this.amount,
  });

  ParsedItem copyWith({CaptureKind? kind, DateTime? when}) => ParsedItem(
        text: text,
        kind: kind ?? this.kind,
        when: when ?? this.when,
        amount: amount,
      );

  String get kindLabel => switch (kind) {
        CaptureKind.task => 'Task',
        CaptureKind.reminder => 'Reminder',
        CaptureKind.expense => 'Expense',
        CaptureKind.note => 'Note',
      };
}

class QuickParse {
  /// Verbs that imply something actionable.
  static const _taskVerbs = [
    'buy', 'call', 'email', 'send', 'submit', 'finish', 'complete', 'pay',
    'book', 'order', 'collect', 'pick up', 'pickup', 'drop', 'return',
    'check', 'review', 'fix', 'clean', 'wash', 'read', 'write', 'study',
    'prepare', 'print', 'renew', 'apply', 'download', 'upload', 'update',
    'meet', 'visit', 'get', 'bring', 'take', 'ask', 'message', 'text',
  ];

  /// Words that imply a time-triggered alert rather than a to-do.
  static const _reminderWords = [
    'remind', 'reminder', 'alarm', 'don\'t forget', 'dont forget',
    'remember to', 'at ', 'before ', 'appointment',
  ];

  static const _expenseWords = [
    'spent', 'paid', 'cost', 'bought for', 'bill', 'recharge', 'fare',
  ];

  /// Split a free-text dump into individual items.
  /// Handles newlines, commas, semicolons, and " and ".
  static List<String> splitItems(String input) {
    final normalized = input
        .replaceAll(RegExp(r'[;\n]+'), ',')
        .replaceAll(RegExp(r'\s+and\s+', caseSensitive: false), ',');
    return normalized
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Parse a whole dump into classified items.
  static List<ParsedItem> parseAll(String input) =>
      splitItems(input).map(parseOne).toList();

  static ParsedItem parseOne(String raw) {
    final text = raw.trim();
    final lower = text.toLowerCase();

    final amount = _extractAmount(lower);
    final when = _extractWhen(lower);

    // Expense wins when there's both money and a spending word.
    if (amount != null &&
        _expenseWords.any((w) => lower.contains(w))) {
      return ParsedItem(
          text: text, kind: CaptureKind.expense, amount: amount, when: when);
    }

    if (_reminderWords.any((w) => lower.contains(w)) || when != null) {
      return ParsedItem(
          text: text, kind: CaptureKind.reminder, when: when, amount: amount);
    }

    if (_taskVerbs.any((v) =>
        lower == v || lower.startsWith('$v ') || lower.contains(' $v '))) {
      return ParsedItem(text: text, kind: CaptureKind.task, amount: amount);
    }

    return ParsedItem(text: text, kind: CaptureKind.note, amount: amount);
  }

  /// Pulls a rupee amount out of text: "500", "rs 500", "₹500", "500rs".
  static double? _extractAmount(String lower) {
    final m = RegExp(r'(?:₹|rs\.?\s*)(\d+(?:\.\d+)?)').firstMatch(lower) ??
        RegExp(r'(\d+(?:\.\d+)?)\s*(?:rs|rupees)').firstMatch(lower);
    if (m == null) return null;
    return double.tryParse(m.group(1)!);
  }

  /// Very small date/time understanding — today / tomorrow / weekday /
  /// "at 5pm" / "at 17:30". Returns null when nothing is recognised.
  static DateTime? _extractWhen(String lower) {
    final now = DateTime.now();
    DateTime? day;

    if (lower.contains('day after tomorrow')) {
      day = DateTime(now.year, now.month, now.day + 2);
    } else if (lower.contains('tomorrow') || lower.contains('tmrw')) {
      day = DateTime(now.year, now.month, now.day + 1);
    } else if (lower.contains('today') || lower.contains('tonight')) {
      day = DateTime(now.year, now.month, now.day);
    } else {
      const weekdays = {
        'monday': 1, 'tuesday': 2, 'wednesday': 3, 'thursday': 4,
        'friday': 5, 'saturday': 6, 'sunday': 7,
      };
      for (final e in weekdays.entries) {
        if (lower.contains(e.key)) {
          var diff = (e.value - now.weekday) % 7;
          if (diff == 0) diff = 7; // "monday" on a Monday means next Monday
          day = DateTime(now.year, now.month, now.day + diff);
          break;
        }
      }
    }

    final time = _extractTime(lower);
    if (day == null && time == null) return null;

    final base = day ?? DateTime(now.year, now.month, now.day);
    if (time == null) {
      // A bare day with no time defaults to 9am.
      return DateTime(base.year, base.month, base.day, 9);
    }
    final result =
        DateTime(base.year, base.month, base.day, time.$1, time.$2);
    // A bare time already past today rolls to tomorrow.
    if (day == null && result.isBefore(now)) {
      return result.add(const Duration(days: 1));
    }
    return result;
  }

  /// Returns (hour, minute) or null.
  static (int, int)? _extractTime(String lower) {
    // 5pm / 5 pm / 5:30pm
    final ampm =
        RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)').firstMatch(lower);
    if (ampm != null) {
      var h = int.parse(ampm.group(1)!);
      final m = int.tryParse(ampm.group(2) ?? '0') ?? 0;
      final isPm = ampm.group(3) == 'pm';
      if (isPm && h != 12) h += 12;
      if (!isPm && h == 12) h = 0;
      if (h < 24 && m < 60) return (h, m);
    }
    // 24-hour "at 17:30"
    final h24 = RegExp(r'at\s+(\d{1,2}):(\d{2})').firstMatch(lower);
    if (h24 != null) {
      final h = int.parse(h24.group(1)!);
      final m = int.parse(h24.group(2)!);
      if (h < 24 && m < 60) return (h, m);
    }
    return null;
  }
}
