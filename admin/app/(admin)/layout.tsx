import type { Metadata } from 'next';
import { getCurrentUser } from '@/lib/api';
import { Sidebar } from '@/components/Sidebar';
import { redirect } from 'next/navigation';
import type { UserRole } from '@/types';

export const metadata: Metadata = {
  title: 'Admin',
};

export default async function AdminShellLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const user = await getCurrentUser();

  if (!user) {
    redirect('/login');
  }

  const allowedRoles: UserRole[] = ['moderator', 'admin'];
  if (!allowedRoles.includes(user.role as UserRole)) {
    redirect('/unauthorized');
  }

  return (
    <div className="admin-shell">
      <Sidebar
        currentRole={user.role as UserRole}
        displayName={user.displayName}
      />
      <main className="admin-main">
        <div className="admin-content">{children}</div>
      </main>
    </div>
  );
}
