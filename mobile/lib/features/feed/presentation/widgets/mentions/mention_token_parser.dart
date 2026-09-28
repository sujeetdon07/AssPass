/// Represents an active mention token detected in a text input relative to the cursor.
class MentionToken {
  const MentionToken({
    required this.startIndex,
    required this.endIndex,
    required this.query,
  });

  /// The UTF-16 index of the '@' symbol in the text.
  final int startIndex;

  /// The UTF-16 index immediately after the last character of the mention token word.
  final int endIndex;

  /// The search query (the characters following '@' up to the current cursor position).
  final String query;

  @override
  String toString() =>
      'MentionToken(start: $startIndex, end: $endIndex, query: "$query")';
}

/// Utility for detecting and extracting active '@mention' triggers in text fields.
class MentionTokenParser {
  MentionTokenParser._();

  static final RegExp _validPrecedingChar = RegExp(r'[\s\(\[\{"\x27<]');
  static final RegExp _validTokenChar = RegExp(r'[a-zA-Z0-9_]');

  /// Parses [text] with the cursor at [cursorPosition] and returns a [MentionToken]
  /// if the cursor is currently inside or at the boundary of an active mention trigger.
  ///
  /// Returns `null` if the cursor is not in an active mention context (e.g., inside an email).
  static MentionToken? findMentionToken(String text, int cursorPosition) {
    if (cursorPosition <= 0 || cursorPosition > text.length) {
      return null;
    }

    // 1. Scan backwards from the character immediately before the cursor.
    int atIndex = -1;
    for (int i = cursorPosition - 1; i >= 0; i--) {
      final char = text[i];
      if (char == '@') {
        atIndex = i;
        break;
      }
      if (!_validTokenChar.hasMatch(char)) {
        // Encountered a non-token character (whitespace, dot, hyphen, etc.) before '@'
        return null;
      }
    }

    if (atIndex == -1) {
      return null;
    }

    // 2. Validate the character preceding '@' (must be start-of-string, whitespace, or open bracket)
    if (atIndex > 0) {
      final precedingChar = text[atIndex - 1];
      if (!_validPrecedingChar.hasMatch(precedingChar)) {
        // Example: 'email@domain.com' - preceding character is alphanumeric, not a trigger.
        return null;
      }
    }

    // 3. Extract the query from after '@' to cursorPosition
    final query = text.substring(atIndex + 1, cursorPosition);

    // 4. Find the token boundary extending after cursorPosition
    int tokenEnd = cursorPosition;
    while (tokenEnd < text.length && _validTokenChar.hasMatch(text[tokenEnd])) {
      tokenEnd++;
    }

    return MentionToken(
      startIndex: atIndex,
      endIndex: tokenEnd,
      query: query,
    );
  }
}
