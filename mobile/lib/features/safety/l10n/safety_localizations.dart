import 'package:flutter/widgets.dart';

/// Localization strings for Aaspaas Trust & Safety in English & Hindi.
class SafetyStrings {
  SafetyStrings._();

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'privacyAndSafety': 'Privacy & Safety',
      'blockedUsers': 'Blocked Users',
      'blockedUsersDesc': 'Manage people you have blocked from contacting you.',
      'reportHistory': 'Report History',
      'reportHistoryDesc': 'Track safety reports you have submitted to our team.',
      'noBlockedUsers': 'No blocked users',
      'noBlockedUsersDesc': 'You have not blocked anyone yet. Blocked users will appear here.',
      'noReportsYet': 'No reports submitted',
      'noReportsYetDesc': 'You have not submitted any safety reports yet. When you report content or users, you can track them here.',
      'blockUser': 'Block User',
      'unblockUser': 'Unblock',
      'blockConfirmMessage': 'Are you sure you want to block this user? They will not be able to message you or see your contact status.',
      'unblockConfirmMessage': 'Are you sure you want to unblock this user? They will be able to message you again.',
      'userBlocked': 'User blocked successfully.',
      'userUnblocked': 'User unblocked successfully.',
      'reportUser': 'Report User',
      'reportContent': 'Report Content',
      'submitReport': 'Submit Report',
      'submitting': 'Submitting…',
      'reportSubmittedSuccess': 'Thank you for keeping Aaspaas safe. Our moderation team will review this report.',
      'reportDuplicateWarning': 'You have already submitted an active report for this item.',
      'reportRateLimitWarning': 'You have submitted too many reports recently. Please try again later.',
      'additionalDetailsHint': 'Provide additional context to help our moderation team (optional, max 2000 characters)…',
      'cancel': 'Cancel',
      'statusPending': 'Pending',
      'statusReviewing': 'Under Review',
      'statusActioned': 'Action Taken',
      'statusDismissed': 'Dismissed',
      'statusDuplicate': 'Duplicate',
    },
    'hi': {
      'privacyAndSafety': 'गोपनीयता और सुरक्षा',
      'blockedUsers': 'ब्लॉक किए गए उपयोगकर्ता',
      'blockedUsersDesc': 'उन लोगों को प्रबंधित करें जिन्हें आपने आपसे संपर्क करने से ब्लॉक किया है।',
      'reportHistory': 'रिपोर्ट इतिहास',
      'reportHistoryDesc': 'हमारी टीम को प्रस्तुत की गई अपनी सुरक्षा रिपोर्टों को ट्रैक करें।',
      'noBlockedUsers': 'कोई ब्लॉक किया गया उपयोगकर्ता नहीं',
      'noBlockedUsersDesc': 'आपने अभी तक किसी को ब्लॉक नहीं किया है।',
      'noReportsYet': 'कोई रिपोर्ट सबमिट नहीं की गई',
      'noReportsYetDesc': 'आपने अभी तक कोई सुरक्षा रिपोर्ट प्रस्तुत नहीं की है।',
      'blockUser': 'उपयोगकर्ता को ब्लॉक करें',
      'unblockUser': 'अनब्लॉक करें',
      'blockConfirmMessage': 'क्या आप वाकई इस उपयोगकर्ता को ब्लॉक करना चाहते हैं? वे आपको संदेश नहीं भेज पाएंगे।',
      'unblockConfirmMessage': 'क्या आप वाकई इस उपयोगकर्ता को अनब्लॉक करना चाहते हैं?',
      'userBlocked': 'उपयोगकर्ता को सफलतापूर्वक ब्लॉक कर दिया गया।',
      'userUnblocked': 'उपयोगकर्ता को सफलतापूर्वक अनब्लॉक कर दिया गया।',
      'reportUser': 'उपयोगकर्ता की रिपोर्ट करें',
      'reportContent': 'सामग्री की रिपोर्ट करें',
      'submitReport': 'रिपोर्ट सबमिट करें',
      'submitting': 'सबमिट किया जा रहा है…',
      'reportSubmittedSuccess': 'आसपास को सुरक्षित रखने के लिए धन्यवाद। हमारी मॉडरेशन टीम इसकी समीक्षा करेगी।',
      'reportDuplicateWarning': 'आपने पहले ही इसके लिए एक सक्रिय रिपोर्ट सबमिट कर दी है।',
      'reportRateLimitWarning': 'आपने हाल ही में बहुत अधिक रिपोर्ट प्रस्तुत की हैं। कृपया बाद में पुनः प्रयास करें।',
      'additionalDetailsHint': 'हमारी टीम की मदद के लिए अतिरिक्त विवरण दें (वैकल्पिक, अधिकतम 2000 अक्षर)…',
      'cancel': 'रद्द करें',
      'statusPending': 'लंबित',
      'statusReviewing': 'समीक्षाधीन',
      'statusActioned': 'कार्रवाई की गई',
      'statusDismissed': 'खारिज',
      'statusDuplicate': 'डुप्लिकेट',
    },
  };

  /// Returns localized string based on current locale or fallback to English.
  static String of(BuildContext context, String key) {
    final locale = Localizations.localeOf(context).languageCode;
    return _localizedValues[locale]?[key] ?? _localizedValues['en']?[key] ?? key;
  }
}
