'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  LayoutDashboard,
  Flag,
  Users,
  Shield,
  ShoppingBag,
  Building2,
  Wrench,
  Users2,
  FileText,
  UserCog,
  LogOut,
  ChevronRight,
} from 'lucide-react';
import { actionLogout } from '@/lib/auth-actions';
import type { UserRole } from '@/types';

interface SidebarProps {
  currentRole: UserRole;
  displayName: string | null;
}

interface NavItem {
  label: string;
  href: string;
  icon: React.ReactNode;
  requiredRoles?: UserRole[];
}

interface NavSection {
  label: string;
  items: NavItem[];
}

const NAV_SECTIONS: NavSection[] = [
  {
    label: 'Overview',
    items: [
      {
        label: 'Dashboard',
        href: '/dashboard',
        icon: <LayoutDashboard className="nav-icon" />,
      },
    ],
  },
  {
    label: 'Moderation',
    items: [
      {
        label: 'Reports',
        href: '/reports',
        icon: <Flag className="nav-icon" />,
      },
      {
        label: 'Users',
        href: '/users',
        icon: <Users className="nav-icon" />,
      },
      {
        label: 'Safety',
        href: '/safety',
        icon: <Shield className="nav-icon" />,
      },
    ],
  },
  {
    label: 'Local',
    items: [
      {
        label: 'Marketplace',
        href: '/marketplace',
        icon: <ShoppingBag className="nav-icon" />,
      },
      {
        label: 'Businesses',
        href: '/businesses',
        icon: <Building2 className="nav-icon" />,
      },
      {
        label: 'Services',
        href: '/services',
        icon: <Wrench className="nav-icon" />,
      },
      {
        label: 'Communities',
        href: '/communities',
        icon: <Users2 className="nav-icon" />,
      },
    ],
  },
  {
    label: 'Administration',
    items: [
      {
        label: 'Audit Logs',
        href: '/audit-logs',
        icon: <FileText className="nav-icon" />,
        requiredRoles: ['admin'],
      },
      {
        label: 'Staff',
        href: '/staff',
        icon: <UserCog className="nav-icon" />,
        requiredRoles: ['admin'],
      },
    ],
  },
];

export function Sidebar({ currentRole, displayName }: SidebarProps) {
  const pathname = usePathname();

  async function handleLogout() {
    await actionLogout();
  }

  return (
    <aside className="admin-sidebar" aria-label="Admin navigation">
      {/* Brand */}
      <div
        style={{
          padding: '20px 20px 16px',
          borderBottom: '1px solid var(--border-subtle)',
        }}
      >
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '10px',
            marginBottom: '12px',
          }}
        >
          <div
            style={{
              width: '32px',
              height: '32px',
              borderRadius: '8px',
              background: 'linear-gradient(135deg, #4f7ef8, #6b91ff)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: '14px',
              fontWeight: '800',
              color: '#fff',
              flexShrink: 0,
            }}
          >
            A
          </div>
          <div>
            <div style={{ fontSize: '14px', fontWeight: '700', color: 'var(--text-primary)' }}>
              Aaspaas
            </div>
            <div style={{ fontSize: '10px', color: 'var(--text-muted)', letterSpacing: '0.5px', textTransform: 'uppercase' }}>
              Admin Dashboard
            </div>
          </div>
        </div>
        {/* Current user */}
        <div
          style={{
            background: 'var(--surface-alt)',
            borderRadius: '8px',
            padding: '8px 10px',
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
          }}
        >
          <div
            style={{
              width: '26px',
              height: '26px',
              borderRadius: '50%',
              background: 'var(--accent-muted)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: '11px',
              fontWeight: '700',
              color: 'var(--accent)',
              flexShrink: 0,
            }}
          >
            {(displayName ?? 'S').charAt(0).toUpperCase()}
          </div>
          <div style={{ flex: 1, overflow: 'hidden' }}>
            <div
              style={{
                fontSize: '12px',
                fontWeight: '600',
                color: 'var(--text-primary)',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap',
              }}
            >
              {displayName ?? 'Staff'}
            </div>
            <div
              className={`badge badge-${currentRole}`}
              style={{ fontSize: '9px', padding: '1px 6px', marginTop: '2px' }}
            >
              {currentRole}
            </div>
          </div>
        </div>
      </div>

      {/* Navigation */}
      <nav style={{ flex: 1, padding: '8px 0' }}>
        {NAV_SECTIONS.map((section) => {
          const visibleItems = section.items.filter(
            (item) =>
              !item.requiredRoles || item.requiredRoles.includes(currentRole),
          );
          if (visibleItems.length === 0) return null;

          return (
            <div key={section.label}>
              <div className="nav-section-label">{section.label}</div>
              {visibleItems.map((item) => {
                const isActive =
                  item.href === '/dashboard'
                    ? pathname === '/dashboard'
                    : pathname.startsWith(item.href);
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    className={`nav-item ${isActive ? 'active' : ''}`}
                    aria-current={isActive ? 'page' : undefined}
                  >
                    {item.icon}
                    <span style={{ flex: 1 }}>{item.label}</span>
                    {isActive && (
                      <ChevronRight
                        size={12}
                        style={{ color: 'var(--accent)', opacity: 0.7 }}
                      />
                    )}
                  </Link>
                );
              })}
            </div>
          );
        })}
      </nav>

      {/* Logout */}
      <div
        style={{
          borderTop: '1px solid var(--border-subtle)',
          padding: '8px',
        }}
      >
        <form action={handleLogout}>
          <button
            type="submit"
            className="nav-item"
            style={{ color: 'var(--danger)', width: '100%' }}
          >
            <LogOut size={15} />
            <span>Sign out</span>
          </button>
        </form>
      </div>
    </aside>
  );
}
