'use client';

import { useActionState, useState } from 'react';
import { actionRequestOtp, actionVerifyOtp } from '@/lib/auth-actions';

type LoginStep = 'phone' | 'otp';

export default function LoginPage() {
  const [phoneNumber, setPhoneNumber] = useState('');
  const [forcedStep, setForcedStep] = useState<LoginStep | null>(null);

  const [otpState, otpAction, otpPending] = useActionState(actionVerifyOtp, {});
  const [phoneState, phoneAction, phonePending] = useActionState(
    actionRequestOtp,
    {},
  );

  const step: LoginStep = forcedStep ?? (phoneState?.success ? 'otp' : 'phone');

  return (
    <div
      style={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: 'var(--background)',
        padding: '24px',
      }}
    >
      <div
        style={{
          width: '100%',
          maxWidth: '400px',
        }}
      >
        {/* Brand */}
        <div style={{ textAlign: 'center', marginBottom: '32px' }}>
          <div
            style={{
              width: '56px',
              height: '56px',
              borderRadius: '14px',
              background: 'linear-gradient(135deg, #4f7ef8, #6b91ff)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: '24px',
              fontWeight: '800',
              color: '#fff',
              margin: '0 auto 16px',
              boxShadow: '0 8px 32px rgba(79, 126, 248, 0.3)',
            }}
          >
            A
          </div>
          <h1
            style={{
              fontSize: '22px',
              fontWeight: '700',
              color: 'var(--text-primary)',
              marginBottom: '4px',
            }}
          >
            Aaspaas Admin
          </h1>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
            Staff access only. Unauthorized access is logged.
          </p>
        </div>

        {/* Login Card */}
        <div
          style={{
            background: 'var(--surface)',
            border: '1px solid var(--border-subtle)',
            borderRadius: '14px',
            padding: '28px',
          }}
        >
          {step === 'phone' ? (
            <form
              action={(formData) => {
                const phone = formData.get('phoneNumber') as string;
                if (phone) setPhoneNumber(phone);
                setForcedStep(null);
                phoneAction(formData);
              }}
            >
              <div style={{ marginBottom: '20px' }}>
                <label
                  htmlFor="phoneNumber"
                  style={{
                    display: 'block',
                    fontSize: '12px',
                    fontWeight: '600',
                    color: 'var(--text-secondary)',
                    marginBottom: '8px',
                    textTransform: 'uppercase',
                    letterSpacing: '0.5px',
                  }}
                >
                  Phone Number
                </label>
                <input
                  id="phoneNumber"
                  name="phoneNumber"
                  type="tel"
                  className="input"
                  placeholder="+91 98765 43210"
                  required
                  autoComplete="tel"
                  aria-label="Phone number for staff login"
                />
                <p
                  style={{
                    fontSize: '11px',
                    color: 'var(--text-muted)',
                    marginTop: '6px',
                  }}
                >
                  Enter your registered staff phone number in E.164 format.
                </p>
              </div>

              {phoneState?.error && (
                <div className="alert alert-error" style={{ marginBottom: '16px' }}>
                  {phoneState.error}
                </div>
              )}

              <button
                type="submit"
                className="btn btn-primary"
                disabled={phonePending}
                style={{ width: '100%', justifyContent: 'center' }}
              >
                {phonePending ? 'Sending OTP...' : 'Send Verification Code'}
              </button>
            </form>
          ) : (
            <form action={otpAction}>
              <input type="hidden" name="phoneNumber" value={phoneNumber} />

              <div
                style={{
                  marginBottom: '16px',
                  padding: '10px 14px',
                  background: 'var(--surface-alt)',
                  borderRadius: '8px',
                  fontSize: '12px',
                  color: 'var(--text-secondary)',
                }}
              >
                OTP sent to <strong style={{ color: 'var(--text-primary)' }}>{phoneNumber}</strong>.{' '}
                <button
                  type="button"
                  onClick={() => setForcedStep('phone')}
                  style={{
                    color: 'var(--accent)',
                    background: 'none',
                    border: 'none',
                    cursor: 'pointer',
                    fontSize: '12px',
                    padding: 0,
                  }}
                >
                  Change
                </button>
                {phoneState?.devOtp && (
                  <div style={{ marginTop: '6px', fontSize: '11px', color: 'var(--accent)', fontWeight: '600' }}>
                    Dev verification code: <code style={{ letterSpacing: '1px' }}>{phoneState.devOtp}</code>
                  </div>
                )}
              </div>

              <div style={{ marginBottom: '20px' }}>
                <label
                  htmlFor="otp"
                  style={{
                    display: 'block',
                    fontSize: '12px',
                    fontWeight: '600',
                    color: 'var(--text-secondary)',
                    marginBottom: '8px',
                    textTransform: 'uppercase',
                    letterSpacing: '0.5px',
                  }}
                >
                  6-Digit Code
                </label>
                <input
                  id="otp"
                  name="otp"
                  type="text"
                  className="input"
                  placeholder="123456"
                  maxLength={6}
                  pattern="[0-9]{6}"
                  required
                  autoComplete="one-time-code"
                  aria-label="6-digit OTP verification code"
                  style={{
                    fontSize: '20px',
                    letterSpacing: '4px',
                    textAlign: 'center',
                    fontWeight: '600',
                  }}
                />
              </div>

              {otpState?.error && (
                <div className="alert alert-error" style={{ marginBottom: '16px' }}>
                  {otpState.error}
                </div>
              )}

              <button
                type="submit"
                className="btn btn-primary"
                disabled={otpPending}
                style={{ width: '100%', justifyContent: 'center' }}
              >
                {otpPending ? 'Verifying...' : 'Verify & Sign In'}
              </button>
            </form>
          )}
        </div>

        <p
          style={{
            textAlign: 'center',
            fontSize: '11px',
            color: 'var(--text-muted)',
            marginTop: '20px',
          }}
        >
          Access restricted to MODERATOR and ADMIN roles only.
          <br />
          Unauthorized access attempts are recorded.
        </p>
      </div>
    </div>
  );
}
