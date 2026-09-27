'use server';

import { updateReportStatus, updateUserRole, updateUserStatus } from '@/lib/api';
import type { ReportStatus, UserRole, UserStatus } from '@/types';

export async function actionUpdateReportStatus(
  reportId: string,
  status: ReportStatus,
  actionReason?: string,
) {
  return await updateReportStatus(reportId, status, actionReason);
}

export async function actionUpdateUserRole(userId: string, role: UserRole) {
  return await updateUserRole(userId, role);
}

export async function actionUpdateUserStatus(
  userId: string,
  accountStatus: UserStatus,
  reason: string,
) {
  return await updateUserStatus(userId, accountStatus, reason);
}
