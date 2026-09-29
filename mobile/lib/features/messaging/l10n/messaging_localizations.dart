import 'package:flutter/widgets.dart';

/// Localization strings for Aaspaas Messaging in English & Hindi.
class MessagingStrings {
  MessagingStrings._();

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'messages': 'Messages',
      'newMessage': 'New message',
      'typeMessage': 'Type a message...',
      'send': 'Send',
      'sending': 'Sending…',
      'sent': 'Sent',
      'failedToSend': 'Failed to send',
      'retry': 'Retry',
      'noMessagesYet': 'No messages yet',
      'noConversationsYet': 'No conversations yet',
      'online': 'Online',
      'offline': 'Offline',
      'typing': 'Typing…',
      'messageUnavailable': 'Message unavailable',
      'conversationUnavailable': 'Conversation unavailable',
      'blockUser': 'Block user',
      'unblockUser': 'Unblock user',
      'reportConversation': 'Report conversation',
      'startConversationPrompt':
          'Connect safely with neighbors in your local community.',
      'messageDeleted': 'This message was deleted',
      'contactSeller': 'Contact Seller',
      'messageOwner': 'Message Business Owner',
      'messageProvider': 'Message Provider',
      'photo': 'Photo',
      'attachImage': 'Attach image',
      'camera': 'Camera',
      'gallery': 'Gallery',
      'optimized': 'Optimized',
      'viewPhoto': 'View photo',
    },
    'hi': {
      'messages': 'संदेश',
      'newMessage': 'नया संदेश',
      'typeMessage': 'संदेश लिखें...',
      'send': 'भेजें',
      'sending': 'भेजा जा रहा है…',
      'sent': 'भेजा गया',
      'failedToSend': 'भेजने में विफल',
      'retry': 'पुनः प्रयास करें',
      'noMessagesYet': 'अभी कोई संदेश नहीं है',
      'noConversationsYet': 'अभी कोई बातचीत नहीं है',
      'online': 'ऑनलाइन',
      'offline': 'ऑफलाइन',
      'typing': 'टाइप कर रहे हैं…',
      'messageUnavailable': 'संदेश अनुपलब्ध है',
      'conversationUnavailable': 'बातचीत अनुपलब्ध है',
      'blockUser': 'उपयोगकर्ता को ब्लॉक करें',
      'unblockUser': 'अनब्लॉक करें',
      'reportConversation': 'बातचीत की रिपोर्ट करें',
      'startConversationPrompt':
          'अपने आस-पास के पड़ोसियों से सुरक्षित रूप से जुड़ें।',
      'messageDeleted': 'यह संदेश हटा दिया गया था',
      'contactSeller': 'विक्रेता से संपर्क करें',
      'messageOwner': 'व्यवसाय मालिक को संदेश भेजें',
      'messageProvider': 'सेवा प्रदाता को संदेश भेजें',
      'photo': 'फ़ोटो',
      'attachImage': 'फ़ोटो जोड़ें',
      'camera': 'कैमरा',
      'gallery': 'गैलरी',
      'optimized': 'अनुकूलित',
      'viewPhoto': 'फ़ोटो देखें',
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
