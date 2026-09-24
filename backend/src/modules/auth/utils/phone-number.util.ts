/**
 * Phone number normalization, validation, and masking utility.
 *
 * Implements international E.164 representation while providing
 * first-class convenience for Indian (+91) numbers.
 */
export class PhoneNumberUtil {
  /**
   * Normalizes a phone number string to international E.164 format (+[countryCode][nationalNumber]).
   *
   * Rules:
   * - Strips whitespace, dashes, parentheses, dots.
   * - If starts with '00', replaces with '+'.
   * - If starts with '0' (trunk prefix common in India/UK), strips leading 0 and prefixes defaultCountryCode (+91).
   * - If 10 digits without leading '+' or country code, prefixes defaultCountryCode (+91).
   * - If already has leading '+', ensures valid E.164 digits only.
   */
  static normalize(rawPhone: string, defaultCountryCode = '+91'): string {
    if (!rawPhone || typeof rawPhone !== 'string') {
      throw new Error('Phone number must be a non-empty string.');
    }

    // Strip all non-digit and non-plus characters
    let cleaned = rawPhone.trim().replace(/[\s\-().]/g, '');

    // Handle '00' international prefix
    if (cleaned.startsWith('00')) {
      cleaned = '+' + cleaned.slice(2);
    }

    // Handle leading single '0' (domestic Indian prefix e.g. 09876543210)
    if (cleaned.startsWith('0') && cleaned.length === 11) {
      cleaned = defaultCountryCode + cleaned.slice(1);
    } else if (/^\d{10}$/.test(cleaned)) {
      // 10 digits national number (e.g. 9876543210)
      cleaned = defaultCountryCode + cleaned;
    } else if (!cleaned.startsWith('+')) {
      // Missing '+' prefix
      cleaned = '+' + cleaned;
    }

    if (!this.isValid(cleaned)) {
      throw new Error(`Invalid phone number format: "${this.mask(cleaned)}"`);
    }

    return cleaned;
  }

  /**
   * Validates whether a phone number matches standard E.164 international format.
   * Format: +[1-9]\d{6,14} (total 8 to 15 digits including country code).
   */
  static isValid(phone: string): boolean {
    if (!phone || typeof phone !== 'string') return false;

    // Standard E.164 regex: '+' followed by 1-3 digits country code and 6-14 national digits
    const e164Regex = /^\+[1-9]\d{6,14}$/;
    if (!e164Regex.test(phone)) return false;

    // Special validation for Indian (+91) numbers: must have exactly 10 national digits starting with 6-9
    if (phone.startsWith('+91')) {
      const national = phone.slice(3);
      return /^[6-9]\d{9}$/.test(national);
    }

    return true;
  }

  /**
   * Masks a phone number for user-facing display or logs.
   * Example: +919876543210 -> "+91 ••••••3210"
   * Example: +14155552671 -> "+1 ••••••2671"
   */
  static mask(phone: string): string {
    if (!phone || typeof phone !== 'string') return '••••';

    const trimmed = phone.trim();
    if (trimmed.length < 5) return '••••';

    // Specialized masking for India (+91)
    if (trimmed.startsWith('+91')) {
      const national = trimmed.slice(3);
      const visibleEnd = national.slice(-4);
      const maskedMiddle = '•'.repeat(Math.max(4, national.length - 4));
      return `+91 ${maskedMiddle}${visibleEnd}`;
    }

    // Specialized masking for +1 (US/Canada)
    if (trimmed.startsWith('+1') && trimmed.length === 12) {
      const national = trimmed.slice(2);
      const visibleEnd = national.slice(-4);
      const maskedMiddle = '•'.repeat(Math.max(4, national.length - 4));
      return `+1 ${maskedMiddle}${visibleEnd}`;
    }

    // Generic international country code (+ followed by 1 to 3 digits)
    const match = trimmed.match(/^(\+\d{1,3}?)(\d{6,})$/);
    if (match && match[1] && match[2]) {
      const countryCode = match[1];
      const national = match[2];
      const visibleEnd = national.slice(-4);
      const maskedMiddle = '•'.repeat(Math.max(4, national.length - 4));
      return `${countryCode} ${maskedMiddle}${visibleEnd}`;
    }

    // Fallback masking
    const visibleEnd = trimmed.slice(-4);
    return `••••••${visibleEnd}`;
  }
}
