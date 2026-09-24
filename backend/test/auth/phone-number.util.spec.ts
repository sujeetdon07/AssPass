import { describe, it, expect } from 'vitest';
import { PhoneNumberUtil } from '../../src/modules/auth/utils/phone-number.util.js';

describe('PhoneNumberUtil', () => {
  describe('normalize', () => {
    it('normalizes 10-digit Indian number by prefixing +91', () => {
      expect(PhoneNumberUtil.normalize('9876543210')).toBe('+919876543210');
    });

    it('handles phone numbers with spaces, dashes, parentheses', () => {
      expect(PhoneNumberUtil.normalize('+91 (987) 654-3210')).toBe('+919876543210');
      expect(PhoneNumberUtil.normalize('98765 43210')).toBe('+919876543210');
    });

    it('handles leading 0 domestic trunk prefix', () => {
      expect(PhoneNumberUtil.normalize('09876543210')).toBe('+919876543210');
    });

    it('handles international 00 prefix', () => {
      expect(PhoneNumberUtil.normalize('00919876543210')).toBe('+919876543210');
    });

    it('preserves valid international numbers', () => {
      expect(PhoneNumberUtil.normalize('+14155552671')).toBe('+14155552671');
      expect(PhoneNumberUtil.normalize('+447911123456')).toBe('+447911123456');
    });

    it('throws error on empty or malformed input', () => {
      expect(() => PhoneNumberUtil.normalize('')).toThrow();
      expect(() => PhoneNumberUtil.normalize('abc1234567')).toThrow();
      expect(() => PhoneNumberUtil.normalize('123')).toThrow();
    });
  });

  describe('isValid', () => {
    it('validates correct Indian E.164 numbers (starting with 6,7,8,9)', () => {
      expect(PhoneNumberUtil.isValid('+919876543210')).toBe(true);
      expect(PhoneNumberUtil.isValid('+918876543210')).toBe(true);
      expect(PhoneNumberUtil.isValid('+917876543210')).toBe(true);
      expect(PhoneNumberUtil.isValid('+916876543210')).toBe(true);
    });

    it('rejects invalid Indian national numbers (starting with 0-5 or wrong length)', () => {
      expect(PhoneNumberUtil.isValid('+911234567890')).toBe(false);
      expect(PhoneNumberUtil.isValid('+91987654321')).toBe(false); // 9 digits
      expect(PhoneNumberUtil.isValid('+9198765432100')).toBe(false); // 11 digits
    });

    it('validates foreign E.164 numbers', () => {
      expect(PhoneNumberUtil.isValid('+14155552671')).toBe(true);
      expect(PhoneNumberUtil.isValid('9876543210')).toBe(false); // missing '+'
    });
  });

  describe('mask', () => {
    it('masks middle digits while leaving country code and last 4 digits visible', () => {
      expect(PhoneNumberUtil.mask('+919876543210')).toBe('+91 ••••••3210');
      expect(PhoneNumberUtil.mask('+14155552671')).toBe('+1 ••••••2671');
    });

    it('handles short or invalid phone numbers safely without crashing', () => {
      expect(PhoneNumberUtil.mask('123')).toBe('••••');
      expect(PhoneNumberUtil.mask('')).toBe('••••');
    });
  });
});
