import 'package:flutter/widgets.dart';

/// Localization strings for Aaspaas Notifications in English & Hindi.
class NotificationsStrings {
  NotificationsStrings._();

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'notifications': 'Notifications',
      'notificationSettings': 'Notification Settings',
      'markAllAsRead': 'Mark all as read',
      'noNotifications': 'No notifications yet',
      'noNotificationsSubtitle':
          'When neighbors interact with your posts or message you, updates will appear here.',
      'all': 'All',
      'unread': 'Unread',
      'messages': 'Messages',
      'social': 'Social',
      'community': 'Community',
      'marketplace': 'Marketplace',
      'business': 'Business & Services',
      'system': 'System',
      'pushNotifications': 'Push Notifications',
      'pushNotificationsSubtitle':
          'Receive updates even when the app is closed',
      'categories': 'Notification Categories',
      'messagesCategoryTitle': 'Direct Messages',
      'messagesCategorySubtitle': 'Chat messages and replies from neighbors',
      'socialCategoryTitle': 'Social & Feed Activity',
      'socialCategorySubtitle': 'Likes, comments, and mentions on your posts',
      'communityCategoryTitle': 'Community Updates',
      'communityCategorySubtitle':
          'Announcements, joins, and neighborhood notices',
      'marketplaceCategoryTitle': 'Marketplace Activity',
      'marketplaceCategorySubtitle': 'Inquiries, offers, and item updates',
      'businessCategoryTitle': 'Business & Service Leads',
      'businessCategorySubtitle': 'Customer inquiries and booking requests',
      'systemCategoryTitle': 'System & Safety Alerts',
      'systemCategorySubtitle':
          'Account security, policy, and critical notices',
      'privacyNote':
          'Privacy Safeguard: Private chat contents and sensitive details are never sent in lock-screen push notifications.',
      'deleteNotification': 'Delete',
      'notificationDeleted': 'Notification deleted',
      'preferencesSaved': 'Preferences updated',
      'loading': 'Loading...',
      'errorLoading': 'Failed to load notifications',
      'retry': 'Retry',
      'justNow': 'Just now',
    },
    'hi': {
      'notifications': 'सूचनाएं',
      'notificationSettings': 'सूचना सेटिंग्स',
      'markAllAsRead': 'सभी पढ़े गए चिह्नित करें',
      'noNotifications': 'अभी कोई सूचना नहीं है',
      'noNotificationsSubtitle':
          'जब पड़ोसी आपकी पोस्ट पर प्रतिक्रिया देंगे या संदेश भेजेंगे, तो अपडेट यहाँ दिखाई देंगे।',
      'all': 'सभी',
      'unread': 'अपठित',
      'messages': 'संदेश',
      'social': 'सामाजिक',
      'community': 'समुदाय',
      'marketplace': 'बाज़ार',
      'business': 'व्यवसाय व सेवाएं',
      'system': 'सिस्टम',
      'pushNotifications': 'पुश सूचनाएं',
      'pushNotificationsSubtitle':
          'ऐप बंद होने पर भी त्वरित अपडेट प्राप्त करें',
      'categories': 'सूचना श्रेणियां',
      'messagesCategoryTitle': 'सीधे संदेश',
      'messagesCategorySubtitle': 'पड़ोसियों से चैट संदेश और उत्तर',
      'socialCategoryTitle': 'सामाजिक और फ़ीड गतिविधि',
      'socialCategorySubtitle': 'आपकी पोस्ट पर लाइक, टिप्पणियाँ और उल्लेख',
      'communityCategoryTitle': 'समुदाय अपडेट',
      'communityCategorySubtitle': 'घोषणाएं, नए सदस्य और पड़ोस की सूचनाएं',
      'marketplaceCategoryTitle': 'बाज़ार गतिविधि',
      'marketplaceCategorySubtitle': 'पूछताछ, ऑफ़र और वस्तु अपडेट',
      'businessCategoryTitle': 'व्यवसाय व सेवा लीड्स',
      'businessCategorySubtitle': 'ग्राहक पूछताछ और बुकिंग अनुरोध',
      'systemCategoryTitle': 'सिस्टम और सुरक्षा अलर्ट',
      'systemCategorySubtitle': 'खाता सुरक्षा और महत्वपूर्ण चेतावनियां',
      'privacyNote':
          'गोपनीयता सुरक्षा: लॉक-स्क्रीन पुश सूचनाओं में निजी चैट सामग्री कभी नहीं दिखाई जाती है।',
      'deleteNotification': 'हटाएं',
      'notificationDeleted': 'सूचना हटा दी गई',
      'preferencesSaved': 'प्राथमिकताएं अपडेट की गईं',
      'loading': 'लोड हो रहा है...',
      'errorLoading': 'सूचनाएं लोड करने में विफल',
      'retry': 'पुनः प्रयास करें',
      'justNow': 'अभी-अभी',
    },
  };

  static String of(BuildContext context, String key) {
    final locale = Localizations.localeOf(context).languageCode;
    final lang = _localizedValues.containsKey(locale) ? locale : 'en';
    return _localizedValues[lang]?[key] ?? _localizedValues['en']?[key] ?? key;
  }

  static String get(String key, [String languageCode = 'en']) {
    final lang =
        _localizedValues.containsKey(languageCode) ? languageCode : 'en';
    return _localizedValues[lang]?[key] ?? _localizedValues['en']?[key] ?? key;
  }
}
