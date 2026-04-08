import 'package:flutter/widgets.dart';

class AppLocalizations {
  final Locale locale;

  const AppLocalizations(this.locale);

  static const supportedLocales = [Locale('en'), Locale('ne')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final localization =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    return localization ?? const AppLocalizations(Locale('en'));
  }

  String get appName => _t('appName');
  String get home => _t('home');
  String get subjects => _t('subjects');
  String get play => _t('play');
  String get ai => _t('ai');
  String get profile => _t('profile');
  String get accessPortal => _t('accessPortal');
  String get login => _t('login');
  String get signup => _t('signup');
  String get welcomeBack => _t('welcomeBack');
  String get createAccount => _t('createAccount');
  String get loginSubtitle => _t('loginSubtitle');
  String get signupSubtitle => _t('signupSubtitle');
  String get email => _t('email');
  String get phone => _t('phone');
  String get password => _t('password');
  String get emailRequired => _t('emailRequired');
  String get phoneRequired => _t('phoneRequired');
  String get validEmail => _t('validEmail');
  String get validPhone => _t('validPhone');
  String get passwordRequired => _t('passwordRequired');
  String get passwordMin => _t('passwordMin');
  String get continueAction => _t('continueAction');
  String get createAccountAction => _t('createAccountAction');
  String get dashboard => _t('dashboard');
  String get quickActions => _t('quickActions');
  String get progressSnapshot => _t('progressSnapshot');
  String get weakTopics => _t('weakTopics');
  String get revisionQueue => _t('revisionQueue');
  String get recommendedNotes => _t('recommendedNotes');
  String get noRecommendations => _t('noRecommendations');
  String get aiPick => _t('aiPick');
  String get welcomeBackShort => _t('welcomeBackShort');
  String get aiAdaptive => _t('aiAdaptive');
  String get pass => _t('pass');
  String get fail => _t('fail');
  String get noAttempts => _t('noAttempts');
  String get aiPersonalCoach => _t('aiPersonalCoach');
  String get aiCoachSubtitle => _t('aiCoachSubtitle');
  String get open => _t('open');
  String get progressShort => _t('progressShort');
  String get progressSubtitle => _t('progressSubtitle');
  String get syllabusSubtitle => _t('syllabusSubtitle');
  String get bcaNotices => _t('bcaNotices');
  String get bcaNoticesSubtitle => _t('bcaNoticesSubtitle');
  String get freeBooks => _t('freeBooks');
  String get freeBooksSubtitle => _t('freeBooksSubtitle');
  String get programmingWorld => _t('programmingWorld');
  String get programmingWorldSubtitle => _t('programmingWorldSubtitle');
  String get xpEarned => _t('xpEarned');
  String get gamesPlayed => _t('gamesPlayed');
  String get noWeakTopics => _t('noWeakTopics');
  String get yourSubjects => _t('yourSubjects');
  String get pickSubject => _t('pickSubject');
  String get openSyllabus => _t('openSyllabus');
  String get openSubject => _t('openSubject');
  String get selectSemesterPrompt => _t('selectSemesterPrompt');
  String get noSubjectsAvailable => _t('noSubjectsAvailable');
  String get noSyllabusAvailable => _t('noSyllabusAvailable');
  String get search => _t('search');
  String get communityQna => _t('communityQna');
  String get studyPlanner => _t('studyPlanner');
  String get studyPlannerSubtitle => _t('studyPlannerSubtitle');
  String get progressTracking => _t('progressTracking');
  String get syllabus => _t('syllabus');
  String get admin => _t('admin');
  String get logout => _t('logout');
  String get logoutTitle => _t('logoutTitle');
  String get logoutMessage => _t('logoutMessage');
  String get cancel => _t('cancel');
  String get language => _t('language');
  String get english => _t('english');
  String get nepali => _t('nepali');
  String get student => _t('student');
  String get adminRole => _t('adminRole');
  String get chooseSubject => _t('chooseSubject');
  String get noSubjects => _t('noSubjects');
  String get reviewNow => _t('reviewNow');
  String get markDone => _t('markDone');
  String get dueToday => _t('dueToday');
  String get dueTomorrow => _t('dueTomorrow');
  String get priorityHigh => _t('priorityHigh');
  String get priorityMedium => _t('priorityMedium');
  String get priorityLow => _t('priorityLow');

  String overallProgressMessage(String percent, String semester) {
    if (locale.languageCode == 'ne') {
      return 'कुल प्रगति: $percent ($semester).';
    }
    return 'Overall progress: $percent for $semester.';
  }

  String subjectSyllabusTitle(String subject) {
    if (locale.languageCode == 'ne') {
      return '$subject पाठ्यक्रम';
    }
    return '$subject syllabus';
  }

  String subjectsCount(int count) {
    if (locale.languageCode == 'ne') {
      return '$count विषय';
    }
    return '$count subjects';
  }

  String chaptersCount(int count) {
    if (locale.languageCode == 'ne') {
      return '$count अध्याय';
    }
    return '$count chapters';
  }

  String quizzesCount(int count) {
    if (locale.languageCode == 'ne') {
      return '$count क्विज';
    }
    return '$count quizzes';
  }

  String dueInDays(int days) {
    if (locale.languageCode == 'ne') {
      return '$days दिनमा';
    }
    return 'In $days days';
  }

  String _t(String key) {
    final lang =
        _localizedValues[locale.languageCode] ?? _localizedValues['en']!;
    final fallback = _localizedValues['en']!;
    return lang[key] ?? fallback[key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any(
        (supported) => supported.languageCode == locale.languageCode,
      );

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}

extension AppLocalizationExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  String tr(String en, String ne) {
    final code = Localizations.localeOf(this).languageCode;
    return code == 'ne' ? ne : en;
  }
}

const Map<String, Map<String, String>> _localizedValues = {
  'en': {
    'appName': 'StudentSurge',
    'home': 'Home',
    'subjects': 'Subjects',
    'play': 'Play',
    'ai': 'AI',
    'profile': 'Profile',
    'dashboard': 'Dashboard',
    'accessPortal': 'Access Portal',
    'login': 'Login',
    'signup': 'Sign Up',
    'welcomeBack': 'Welcome back',
    'welcomeBackShort': 'Welcome back,',
    'createAccount': 'Create your account',
    'loginSubtitle': 'Sign in to continue your study streak.',
    'signupSubtitle': 'Start in seconds with email or phone.',
    'email': 'Email',
    'phone': 'Phone',
    'password': 'Password',
    'emailRequired': 'Email is required',
    'phoneRequired': 'Phone is required',
    'validEmail': 'Enter a valid email',
    'validPhone': 'Enter a valid phone number',
    'passwordRequired': 'Password is required',
    'passwordMin': 'Minimum 6 characters',
    'continueAction': 'Continue',
    'createAccountAction': 'Create Account',
    'quickActions': 'Quick actions',
    'progressSnapshot': 'Progress Snapshot',
    'weakTopics': 'Weak Topics',
    'revisionQueue': 'Revision Queue',
    'recommendedNotes': 'Recommended Notes',
    'noRecommendations': 'No recommendations yet.',
    'aiPick': 'AI pick',
    'aiAdaptive': 'AI Adaptive',
    'pass': 'Pass',
    'fail': 'Fail',
    'noAttempts': 'No attempts',
    'aiPersonalCoach': 'AI Personal Coach',
    'aiCoachSubtitle': 'Weak topics, daily plan, and 10 questions.',
    'open': 'Open',
    'search': 'Search',
    'communityQna': 'Community Q&A',
    'studyPlanner': 'Study Planner',
    'studyPlannerSubtitle': 'Plan your week',
    'progressTracking': 'Progress Tracking',
    'progressShort': 'Progress',
    'progressSubtitle': 'Track growth',
    'syllabus': 'Syllabus',
    'syllabusSubtitle': 'Official PDFs',
    'bcaNotices': 'BCA Notices',
    'bcaNoticesSubtitle': 'TU updates',
    'freeBooks': 'Free Books',
    'freeBooksSubtitle': 'Open textbooks',
    'programmingWorld': 'Programming World',
    'programmingWorldSubtitle': 'Tracks & practice',
    'xpEarned': 'XP earned',
    'gamesPlayed': 'Games played',
    'noWeakTopics': 'No weak topics detected yet.',
    'yourSubjects': 'Your Subjects',
    'pickSubject': 'Pick a subject to explore notes and quizzes.',
    'openSyllabus': 'Open syllabus',
    'openSubject': 'Open Subject',
    'selectSemesterPrompt': 'Select a semester to load subjects.',
    'noSubjectsAvailable': 'No subjects available.',
    'noSyllabusAvailable': 'No syllabus available yet.',
    'admin': 'Admin',
    'logout': 'Logout',
    'logoutTitle': 'Logout',
    'logoutMessage': 'Are you sure you want to logout?',
    'cancel': 'Cancel',
    'language': 'Language',
    'english': 'English',
    'nepali': 'Nepali',
    'student': 'Student',
    'adminRole': 'Admin',
    'chooseSubject': 'Choose a subject to view questions.',
    'noSubjects': 'No subjects available yet.',
    'reviewNow': 'Review now',
    'markDone': 'Mark done',
    'dueToday': 'Due today',
    'dueTomorrow': 'Due tomorrow',
    'priorityHigh': 'High priority',
    'priorityMedium': 'Medium priority',
    'priorityLow': 'Low priority',
  },
  'ne': {
    'appName': 'स्टुडेन्टसर्ज',
    'home': 'गृह',
    'subjects': 'विषयहरू',
    'play': 'खेल',
    'ai': 'एआई',
    'profile': 'प्रोफाइल',
    'dashboard': 'ड्यासबोर्ड',
    'accessPortal': 'प्रवेश पोर्टल',
    'login': 'लगइन',
    'signup': 'साइन अप',
    'welcomeBack': 'पुनः स्वागत छ',
    'welcomeBackShort': 'पुनः स्वागत छ,',
    'createAccount': 'खाता बनाउनुहोस्',
    'loginSubtitle': 'पढाइ जारी राख्न लगइन गर्नुहोस्।',
    'signupSubtitle': 'इमेल वा फोनबाट सेकेन्डमै सुरु गर्नुहोस्।',
    'email': 'इमेल',
    'phone': 'फोन',
    'password': 'पासवर्ड',
    'emailRequired': 'इमेल आवश्यक छ',
    'phoneRequired': 'फोन आवश्यक छ',
    'validEmail': 'मान्य इमेल लेख्नुहोस्',
    'validPhone': 'मान्य फोन नम्बर लेख्नुहोस्',
    'passwordRequired': 'पासवर्ड आवश्यक छ',
    'passwordMin': 'कम्तीमा ६ अक्षर',
    'continueAction': 'अगाडि बढ्नुहोस्',
    'createAccountAction': 'खाता सिर्जना गर्नुहोस्',
    'quickActions': 'छिटो कार्य',
    'progressSnapshot': 'प्रगति सारांश',
    'weakTopics': 'कमजोर विषयहरू',
    'revisionQueue': 'पुनरावलोकन सूची',
    'recommendedNotes': 'सिफारिस नोटहरू',
    'noRecommendations': 'अहिले कुनै सिफारिस छैन।',
    'aiPick': 'एआई छनोट',
    'aiAdaptive': 'एआई अनुकूल',
    'pass': 'उत्तीर्ण',
    'fail': 'अनुत्तीर्ण',
    'noAttempts': 'कुनै प्रयास छैन',
    'aiPersonalCoach': 'एआई पर्सनल कोच',
    'aiCoachSubtitle': 'कमजोर विषय, दैनिक योजना, र १० प्रश्न।',
    'open': 'खोल्नुहोस्',
    'search': 'खोज',
    'communityQna': 'समुदाय Q&A',
    'studyPlanner': 'अध्ययन योजना',
    'studyPlannerSubtitle': 'साप्ताहिक योजना बनाउनुहोस्',
    'progressTracking': 'प्रगति ट्र्याकिङ',
    'progressShort': 'प्रगति',
    'progressSubtitle': 'प्रगति हेर्नुहोस्',
    'syllabus': 'पाठ्यक्रम',
    'syllabusSubtitle': 'आधिकारिक PDF',
    'bcaNotices': 'BCA सूचना',
    'bcaNoticesSubtitle': 'TU अपडेट',
    'freeBooks': 'नि:शुल्क पुस्तक',
    'freeBooksSubtitle': 'खुला पाठ्यपुस्तक',
    'programmingWorld': 'प्रोग्रामिङ वर्ल्ड',
    'programmingWorldSubtitle': 'अभ्यास र ट्र्याक',
    'xpEarned': 'XP कमाइयो',
    'gamesPlayed': 'खेलिएको खेल',
    'noWeakTopics': 'कमजोर विषय भेटिएन।',
    'yourSubjects': 'तपाईंका विषयहरू',
    'pickSubject': 'नोट र क्विज हेर्न विषय छनोट गर्नुहोस्।',
    'openSyllabus': 'पाठ्यक्रम खोल्नुहोस्',
    'openSubject': 'विषय खोल्नुहोस्',
    'selectSemesterPrompt': 'विषयहरू लोड गर्न सेमेस्टर छान्नुहोस्।',
    'noSubjectsAvailable': 'कुनै विषय उपलब्ध छैन।',
    'noSyllabusAvailable': 'अहिले पाठ्यक्रम उपलब्ध छैन।',
    'admin': 'एडमिन',
    'logout': 'लगआउट',
    'logoutTitle': 'लगआउट',
    'logoutMessage': 'तपाईं लगआउट गर्न चाहनुहुन्छ?',
    'cancel': 'रद्द गर्नुहोस्',
    'language': 'भाषा',
    'english': 'अंग्रेजी',
    'nepali': 'नेपाली',
    'student': 'विद्यार्थी',
    'adminRole': 'एडमिन',
    'chooseSubject': 'प्रश्नहरू हेर्न विषय चयन गर्नुहोस्।',
    'noSubjects': 'अहिले कुनै विषय उपलब्ध छैन।',
    'reviewNow': 'अहिले पढ्नुहोस्',
    'markDone': 'पूरा भयो',
    'dueToday': 'आज',
    'dueTomorrow': 'भोलि',
    'priorityHigh': 'उच्च प्राथमिकता',
    'priorityMedium': 'मध्यम प्राथमिकता',
    'priorityLow': 'कम प्राथमिकता',
  },
};
