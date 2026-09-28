import { RESERVED_USERNAMES } from '../constants/reserved-usernames.js';

export interface UsernameValidationResult {
  isValid: boolean;
  normalized: string;
  error?: string;
}

export class UsernameValidator {
  /**
   * Regex allowing 3 to 30 characters consisting strictly of
   * lowercase alphanumeric characters and underscores.
   */
  private static readonly USERNAME_REGEX = /^[a-z0-9_]{3,30}$/;

  /**
   * Normalizes a raw input username:
   * - Strips leading '@' if present
   * - Trims surrounding whitespace
   * - Converts to lowercase
   */
  static normalize(raw: string): string {
    if (!raw) return '';
    let cleaned = raw.trim();
    if (cleaned.startsWith('@')) {
      cleaned = cleaned.substring(1);
    }
    return cleaned.toLowerCase();
  }

  /**
   * Validates a username according to Aaspaas public identity rules:
   * 1. 3 to 30 characters
   * 2. Letters, numbers, and underscores only (no spaces, hyphens, periods, or emojis)
   * 3. Cannot be a reserved system name
   */
  static validate(raw: string): UsernameValidationResult {
    const normalized = this.normalize(raw);

    if (!normalized || normalized.length < 3) {
      return {
        isValid: false,
        normalized,
        error: 'Username must be at least 3 characters.',
      };
    }

    if (normalized.length > 30) {
      return {
        isValid: false,
        normalized,
        error: 'Username cannot exceed 30 characters.',
      };
    }

    if (!this.USERNAME_REGEX.test(normalized)) {
      return {
        isValid: false,
        normalized,
        error: 'Username can only contain letters, numbers, and underscores (_).',
      };
    }

    if (RESERVED_USERNAMES.has(normalized)) {
      return {
        isValid: false,
        normalized,
        error: 'This username is reserved for system use.',
      };
    }

    return {
      isValid: true,
      normalized,
    };
  }
}
