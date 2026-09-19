import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight in-app localization (English + Hindi) without extra tooling.
/// Add new keys to both maps. Use context.t('key').
class AppStrings {
  static const Map<String, Map<String, String>> _values = {
    'en': {
      'app_name': 'DailyHub',
      'tagline': 'Your whole day, in one place',
      'login': 'Login',
      'signup': 'Sign Up',
      'email': 'Email Address',
      'password': 'Password',
      'need_account': 'Need an account? Sign up',
      'have_account': 'Already have an account? Login',
      'sign_in_google': 'Sign in with Google',
      'logout': 'Logout',
      'dashboard': 'Home',
      'todos': 'To-Dos',
      'trips': 'Trips',
      'notes': 'Notes',
      'reminders': 'Reminders',
      'habits': 'Habits',
      'expenses': 'Expenses',
      'goals': 'Goals',
      'journal': 'Journal',
      'bookmarks': 'Bookmarks',
      'calendar': 'Calendar',
      'search': 'Search',
      'settings': 'Settings',
      'more': 'More',
      'quick_capture': 'Quick Capture',
      'quick_note_hint': 'Jot an idea before it escapes...',
      'save': 'Save',
      'add': 'Add',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'edit': 'Edit',
      'done': 'Done',
      'title': 'Title',
      'description': 'Description',
      'priority': 'Priority',
      'low': 'Low',
      'medium': 'Medium',
      'high': 'High',
      'date': 'Date',
      'time': 'Time',
      'today': 'Today',
      'tomorrow': 'Tomorrow',
      'upcoming': 'Upcoming',
      'completed': 'Completed',
      'cancelled': 'Cancelled',
      'nothing_here': 'Nothing here yet',
      'good_morning': 'Good morning',
      'good_afternoon': 'Good afternoon',
      'good_evening': 'Good evening',
      'dark_mode': 'Dark mode',
      'language': 'Language',
      'export_data': 'Export my data (JSON)',
      'account': 'Account',
      'notifications': 'Notifications',
      'streak': 'streak',
      'total_spent': 'Total spent',
      'this_month': 'This month',
      'add_expense': 'Add expense',
      'amount': 'Amount',
      'category': 'Category',
      'mark_done': 'Mark done',
      'progress': 'Progress',
      'mood': 'Mood',
      'how_was_day': 'How was your day?',
      'open_link': 'Open link',
      'url': 'URL',
      'due': 'Due',
      'no_due_date': 'No due date',
      'repeat': 'Repeat',
      'once': 'Once',
      'daily': 'Daily',
      'weekly': 'Weekly',
      'monthly': 'Monthly',
    },
    'hi': {
      'app_name': 'DailyHub',
      'tagline': 'आपका पूरा दिन, एक ही जगह',
      'login': 'लॉगिन',
      'signup': 'साइन अप',
      'email': 'ईमेल पता',
      'password': 'पासवर्ड',
      'need_account': 'खाता नहीं है? साइन अप करें',
      'have_account': 'पहले से खाता है? लॉगिन करें',
      'sign_in_google': 'Google से साइन इन करें',
      'logout': 'लॉगआउट',
      'dashboard': 'होम',
      'todos': 'कार्य',
      'trips': 'यात्राएँ',
      'notes': 'नोट्स',
      'reminders': 'रिमाइंडर',
      'habits': 'आदतें',
      'expenses': 'खर्च',
      'goals': 'लक्ष्य',
      'journal': 'डायरी',
      'bookmarks': 'बुकमार्क',
      'calendar': 'कैलेंडर',
      'search': 'खोजें',
      'settings': 'सेटिंग्स',
      'more': 'और',
      'quick_capture': 'तुरंत लिखें',
      'quick_note_hint': 'विचार भूलने से पहले लिख लें...',
      'save': 'सेव करें',
      'add': 'जोड़ें',
      'cancel': 'रद्द करें',
      'delete': 'हटाएँ',
      'edit': 'बदलें',
      'done': 'पूर्ण',
      'title': 'शीर्षक',
      'description': 'विवरण',
      'priority': 'प्राथमिकता',
      'low': 'कम',
      'medium': 'मध्यम',
      'high': 'ज़्यादा',
      'date': 'तारीख',
      'time': 'समय',
      'today': 'आज',
      'tomorrow': 'कल',
      'upcoming': 'आने वाले',
      'completed': 'पूर्ण',
      'cancelled': 'रद्द',
      'nothing_here': 'अभी कुछ नहीं है',
      'good_morning': 'सुप्रभात',
      'good_afternoon': 'नमस्कार',
      'good_evening': 'शुभ संध्या',
      'dark_mode': 'डार्क मोड',
      'language': 'भाषा',
      'export_data': 'मेरा डेटा एक्सपोर्ट करें (JSON)',
      'account': 'खाता',
      'notifications': 'सूचनाएँ',
      'streak': 'लगातार',
      'total_spent': 'कुल खर्च',
      'this_month': 'इस महीने',
      'add_expense': 'खर्च जोड़ें',
      'amount': 'राशि',
      'category': 'श्रेणी',
      'mark_done': 'पूर्ण करें',
      'progress': 'प्रगति',
      'mood': 'मनोदशा',
      'how_was_day': 'आपका दिन कैसा रहा?',
      'open_link': 'लिंक खोलें',
      'url': 'लिंक',
      'due': 'नियत',
      'no_due_date': 'कोई तारीख नहीं',
      'repeat': 'दोहराएँ',
      'once': 'एक बार',
      'daily': 'रोज़',
      'weekly': 'साप्ताहिक',
      'monthly': 'मासिक',
    },
  };

  static String of(String lang, String key) =>
      _values[lang]?[key] ?? _values['en']?[key] ?? key;
}

class LocaleProvider extends ChangeNotifier {
  String _lang = 'en';
  String get lang => _lang;
  Locale get locale => Locale(_lang);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _lang = prefs.getString('lang') ?? 'en';
    notifyListeners();
  }

  Future<void> setLang(String lang) async {
    _lang = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', lang);
    notifyListeners();
  }
}

extension TranslateX on BuildContext {
  String t(String key) {
    // Reads current LocaleProvider without a listen rebuild storm.
    final lang = LocaleScope.of(this);
    return AppStrings.of(lang, key);
  }
}

/// Simple inherited holder so context.t() works everywhere.
class LocaleScope extends InheritedWidget {
  final String lang;
  const LocaleScope({super.key, required this.lang, required super.child});

  static String of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    return scope?.lang ?? 'en';
  }

  @override
  bool updateShouldNotify(LocaleScope oldWidget) => oldWidget.lang != lang;
}
