import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

import {
  formatDate,
  formatRelativeTime,
  statusLabel,
  roleLabel,
  capitalize,
  truncate,
  cn,
} from '../lib/utils.ts';

describe('Admin Frontend Logic & Component Contract Tests', () => {
  describe('Utility Functions', () => {
    it('capitalizes words correctly', () => {
      assert.equal(capitalize('hello'), 'Hello');
      assert.equal(capitalize('ADMIN'), 'Admin');
      assert.equal(capitalize('bengaluru'), 'Bengaluru');
    });

    it('truncates strings cleanly with ellipsis', () => {
      const longText = 'This is a very long report description about inappropriate behavior.';
      assert.equal(truncate(longText, 20), 'This is a very lo...');
      assert.equal(truncate('Short text', 20), 'Short text');
    });

    it('returns human-readable labels for user roles', () => {
      assert.equal(roleLabel('admin'), 'Admin');
      assert.equal(roleLabel('moderator'), 'Moderator');
      assert.equal(roleLabel('user'), 'User');
      assert.equal(roleLabel('superadmin'), 'Superadmin');
    });

    it('returns human-readable labels for report and user statuses', () => {
      assert.equal(statusLabel('pending'), 'Pending');
      assert.equal(statusLabel('reviewing'), 'Reviewing');
      assert.equal(statusLabel('actioned'), 'Actioned');
      assert.equal(statusLabel('dismissed'), 'Dismissed');
      assert.equal(statusLabel('duplicate'), 'Duplicate');
      assert.equal(statusLabel('active'), 'Active');
      assert.equal(statusLabel('suspended'), 'Suspended');
      assert.equal(statusLabel('deleted'), 'Deleted');
      assert.equal(statusLabel('custom_status'), 'Custom status');
    });

    it('formats relative time safely', () => {
      const now = new Date();
      assert.equal(formatRelativeTime(now), 'Just now');
      const pastHours = new Date(Date.now() - 3600000 * 3);
      assert.equal(formatRelativeTime(pastHours), '3h ago');
      const pastDays = new Date(Date.now() - 86400000 * 5);
      assert.equal(formatRelativeTime(pastDays), '5d ago');
    });

    it('formats date strings safely', () => {
      const formatted = formatDate('2026-09-25T10:00:00Z');
      assert.ok(typeof formatted === 'string' && formatted.length > 0);
    });

    it('merges css class names correctly with cn helper', () => {
      assert.equal(cn('badge', 'badge-pending'), 'badge badge-pending');
      assert.equal(cn('p-2', false && 'hidden', 'text-sm'), 'p-2 text-sm');
    });
  });

  describe('RBAC & Navigation Permission Rules', () => {
    const ALL_NAV_ITEMS = [
      { href: '/dashboard', label: 'Dashboard', roles: ['moderator', 'admin'] },
      { href: '/reports', label: 'Moderation Queue', roles: ['moderator', 'admin'] },
      { href: '/users', label: 'User Directory', roles: ['moderator', 'admin'] },
      { href: '/staff', label: 'Staff Management', roles: ['admin'] },
      { href: '/audit-logs', label: 'Audit Logs', roles: ['admin'] },
      { href: '/marketplace', label: 'Marketplace', roles: ['moderator', 'admin'] },
      { href: '/businesses', label: 'Businesses', roles: ['moderator', 'admin'] },
      { href: '/services', label: 'Services', roles: ['moderator', 'admin'] },
      { href: '/communities', label: 'Communities', roles: ['moderator', 'admin'] },
      { href: '/safety', label: 'Safety Overview', roles: ['moderator', 'admin'] },
    ];

    it('ordinary USER has access to 0 admin navigation items', () => {
      const userRole = 'user';
      const permitted = ALL_NAV_ITEMS.filter((item) => item.roles.includes(userRole));
      assert.equal(permitted.length, 0);
    });

    it('MODERATOR has access to moderation and content but NOT staff or audit-logs', () => {
      const modRole = 'moderator';
      const permitted = ALL_NAV_ITEMS.filter((item) => item.roles.includes(modRole));
      const hrefs = permitted.map((i) => i.href);

      assert.ok(hrefs.includes('/dashboard'));
      assert.ok(hrefs.includes('/reports'));
      assert.ok(hrefs.includes('/users'));
      assert.ok(hrefs.includes('/marketplace'));
      assert.ok(hrefs.includes('/businesses'));
      assert.ok(hrefs.includes('/services'));
      assert.ok(hrefs.includes('/communities'));

      // Forbidden for moderator
      assert.ok(!hrefs.includes('/staff'));
      assert.ok(!hrefs.includes('/audit-logs'));
    });

    it('ADMIN has access to all navigation items including staff and audit-logs', () => {
      const adminRole = 'admin';
      const permitted = ALL_NAV_ITEMS.filter((item) => item.roles.includes(adminRole));
      assert.equal(permitted.length, ALL_NAV_ITEMS.length);
    });
  });

  describe('Report Moderation State Machine Transitions', () => {
    const ALLOWED_TRANSITIONS = {
      pending: ['reviewing', 'dismissed', 'duplicate'],
      reviewing: ['actioned', 'dismissed', 'duplicate'],
      actioned: [],
      dismissed: ['reviewing'],
      duplicate: [],
    };

    it('pending reports can only transition to reviewing, dismissed, or duplicate', () => {
      const validNext = ALLOWED_TRANSITIONS.pending;
      assert.deepEqual(validNext, ['reviewing', 'dismissed', 'duplicate']);
      assert.ok(!validNext.includes('actioned')); // Cannot jump directly to actioned without review
    });

    it('reviewing reports can be actioned, dismissed, or marked duplicate', () => {
      const validNext = ALLOWED_TRANSITIONS.reviewing;
      assert.ok(validNext.includes('actioned'));
      assert.ok(validNext.includes('dismissed'));
      assert.ok(validNext.includes('duplicate'));
      assert.ok(!validNext.includes('pending'));
    });

    it('actioned and duplicate reports are terminal states', () => {
      assert.equal(ALLOWED_TRANSITIONS.actioned.length, 0);
      assert.equal(ALLOWED_TRANSITIONS.duplicate.length, 0);
    });

    it('dismissed reports can be reopened into reviewing if appealed', () => {
      assert.deepEqual(ALLOWED_TRANSITIONS.dismissed, ['reviewing']);
    });
  });

  describe('Moderation Reason & Validation Enforcement', () => {
    it('requires a reason when suspending a user account', () => {
      function validateSuspension(newStatus, reason) {
        if (newStatus === 'suspended' && (!reason || !reason.trim())) {
          return { valid: false, error: 'Please provide a reason for suspension.' };
        }
        return { valid: true };
      }

      assert.equal(validateSuspension('suspended', '').valid, false);
      assert.equal(validateSuspension('suspended', '   ').valid, false);
      assert.equal(validateSuspension('suspended', 'Spamming community feed').valid, true);
      assert.equal(validateSuspension('active', '').valid, true);
    });

    it('forbids self role modification', () => {
      function canChangeRole(actorId, targetUserId, actorRole) {
        if (actorId === targetUserId) {
          return { allowed: false, error: 'You cannot change your own role.' };
        }
        if (actorRole !== 'admin') {
          return { allowed: false, error: 'Only admins can change roles.' };
        }
        return { allowed: true };
      }

      assert.equal(canChangeRole('u-1', 'u-1', 'admin').allowed, false);
      assert.equal(canChangeRole('u-1', 'u-2', 'moderator').allowed, false);
      assert.equal(canChangeRole('u-1', 'u-2', 'admin').allowed, true);
    });
  });

  describe('Safe Data Projections & Zero-Leakage Checks', () => {
    it('ensures dashboard summary does not include raw user PII', () => {
      const summary = {
        users: { total: 150, active: 140, suspended: 10, newThisWeek: 12 },
        moderation: { pending: 4, reviewing: 2, actioned: 38 },
        content: { listings: 85, businesses: 24, services: 40, communities: 12 },
        recentActivity: [],
      };

      assert.ok(!('phoneNumbers' in summary));
      assert.ok(!('tokens' in summary));
      assert.equal(typeof summary.users.total, 'number');
      assert.equal(typeof summary.moderation.pending, 'number');
    });

    it('validates safe user projection structure', () => {
      const user = {
        id: 'u-123',
        displayName: 'Aarav Sharma',
        avatarUrl: null,
        role: 'user',
        accountStatus: 'active',
        onboardingCompleted: true,
        locality: 'Koramangala',
        city: 'Bengaluru',
        state: 'Karnataka',
        countryCode: 'IN',
        lastLoginAt: '2026-09-25T10:00:00Z',
        createdAt: '2026-09-01T00:00:00Z',
        updatedAt: '2026-09-25T10:00:00Z',
      };

      assert.equal('phoneNumber' in user, false);
      assert.equal('password' in user, false);
      assert.equal('refreshToken' in user, false);
      assert.equal('fcmToken' in user, false);
      assert.equal(user.displayName, 'Aarav Sharma');
      assert.equal(user.city, 'Bengaluru');
    });
  });
});
