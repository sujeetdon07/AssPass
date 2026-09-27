import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatDate(date: string | Date): string {
  return new Date(date).toLocaleDateString('en-IN', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

export function formatRelativeTime(date: string | Date): string {
  const now = new Date();
  const d = new Date(date);
  const diff = now.getTime() - d.getTime();
  const seconds = Math.floor(diff / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);

  if (days > 30) return formatDate(d);
  if (days > 0) return `${days}d ago`;
  if (hours > 0) return `${hours}h ago`;
  if (minutes > 0) return `${minutes}m ago`;
  return 'Just now';
}

export function truncate(str: string, maxLen: number): string {
  if (str.length <= maxLen) return str;
  return str.slice(0, maxLen - 3) + '...';
}

export function capitalize(str: string): string {
  return str.charAt(0).toUpperCase() + str.slice(1).toLowerCase();
}

export function roleLabel(role: string): string {
  switch (role) {
    case 'admin': return 'Admin';
    case 'moderator': return 'Moderator';
    case 'user': return 'User';
    default: return capitalize(role);
  }
}

export function statusLabel(status: string): string {
  switch (status) {
    case 'active': return 'Active';
    case 'suspended': return 'Suspended';
    case 'deleted': return 'Deleted';
    case 'pending': return 'Pending';
    case 'reviewing': return 'Reviewing';
    case 'actioned': return 'Actioned';
    case 'dismissed': return 'Dismissed';
    case 'duplicate': return 'Duplicate';
    default: return capitalize(status.replace(/_/g, ' '));
  }
}
