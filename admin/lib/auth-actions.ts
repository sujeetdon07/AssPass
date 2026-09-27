'use server';

import { redirect } from 'next/navigation';
import { verifyOtp, requestOtp, setTokenCookies, clearTokenCookies, getCurrentUser } from '@/lib/api';
import type { UserRole } from '@/types';

export async function actionRequestOtp(
  _prevState: { error?: string; success?: boolean; devOtp?: string },
  formData: FormData,
): Promise<{ error?: string; success?: boolean; devOtp?: string }> {
  const phoneNumber = formData.get('phoneNumber') as string;

  if (!phoneNumber) {
    return { error: 'Phone number is required.' };
  }

  try {
    const res = await requestOtp(phoneNumber);
    return { success: true, devOtp: res.devOtp };
  } catch (err) {
    const msg = err instanceof Error ? err.message : 'Failed to send OTP.';
    return { error: msg };
  }
}

export async function actionVerifyOtp(
  _prevState: { error?: string },
  formData: FormData,
): Promise<{ error?: string }> {
  const phoneNumber = formData.get('phoneNumber') as string;
  const otp = formData.get('otp') as string;

  if (!phoneNumber || !otp) {
    return { error: 'Phone number and OTP are required.' };
  }

  try {
    const auth = await verifyOtp(phoneNumber, otp);

    // Verify account is active before setting cookies
    if (auth.user.accountStatus !== 'active') {
      return { error: 'Your account is not active.' };
    }

    await setTokenCookies(
      auth.tokens.accessToken,
      auth.tokens.refreshToken,
      auth.tokens.expiresIn,
    );

    // Verify role after login
    const me = await getCurrentUser();
    if (!me) {
      await clearTokenCookies();
      return { error: 'Authentication failed.' };
    }

    const allowedRoles: UserRole[] = ['moderator', 'admin'];
    if (!allowedRoles.includes(me.role)) {
      await clearTokenCookies();
      return { error: 'Access denied. This dashboard is for staff members only.' };
    }
  } catch (err) {
    const msg = err instanceof Error ? err.message : 'OTP verification failed.';
    return { error: msg };
  }

  redirect('/dashboard');
}

export async function actionLogout(): Promise<void> {
  try {
    const { logout } = await import('@/lib/api');
    await logout();
  } catch {
    await clearTokenCookies();
  }
  redirect('/login');
}

export async function requireAuth(
  requiredRoles: UserRole[] = ['moderator', 'admin'],
): Promise<{ id: string; role: UserRole; displayName: string | null }> {
  const user = await getCurrentUser();

  if (!user) {
    redirect('/login');
  }

  if (!requiredRoles.includes(user.role as UserRole)) {
    redirect('/unauthorized');
  }

  return {
    id: user.id,
    role: user.role as UserRole,
    displayName: user.displayName,
  };
}
