export const OTP_PROVIDER = Symbol('OTP_PROVIDER');

export interface OtpProvider {
  /**
   * Send an OTP to the specified normalized international phone number.
   * @param phoneNumber Normalized E.164 phone number (e.g. "+919876543210")
   * @param otp 6-digit verification code
   */
  sendOtp(phoneNumber: string, otp: string): Promise<void>;
}
