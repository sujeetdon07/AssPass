import { cn, statusLabel } from '@/lib/utils';
import type { ReportStatus, UserRole, UserStatus } from '@/types';

interface StatusBadgeProps {
  status: ReportStatus | UserStatus | string;
  className?: string;
}

export function StatusBadge({ status, className }: StatusBadgeProps) {
  const statusKey = status.toLowerCase().replace(' ', '_');
  return (
    <span
      className={cn(`badge badge-${statusKey}`, className)}
      role="status"
      aria-label={`Status: ${statusLabel(statusKey)}`}
    >
      {statusLabel(statusKey)}
    </span>
  );
}

interface RoleBadgeProps {
  role: UserRole | string;
  className?: string;
}

export function RoleBadge({ role, className }: RoleBadgeProps) {
  return (
    <span className={cn(`badge badge-${role}`, className)}>
      {role}
    </span>
  );
}

interface SkeletonProps {
  className?: string;
  height?: number;
  width?: string;
}

export function Skeleton({ className, height = 16, width = '100%' }: SkeletonProps) {
  return (
    <div
      className={cn('skeleton', className)}
      style={{ height, width }}
      role="status"
      aria-label="Loading..."
    />
  );
}

export function SkeletonRow({ cols }: { cols: number }) {
  return (
    <tr>
      {Array.from({ length: cols }).map((_, i) => (
        <td key={i} style={{ padding: '12px' }}>
          <Skeleton />
        </td>
      ))}
    </tr>
  );
}

export function SkeletonCard() {
  return (
    <div className="metric-card">
      <Skeleton height={12} width="60%" />
      <Skeleton height={32} width="40%" />
      <Skeleton height={12} width="80%" />
    </div>
  );
}

interface EmptyStateProps {
  title: string;
  description?: string;
  icon?: React.ReactNode;
}

export function EmptyState({ title, description, icon }: EmptyStateProps) {
  return (
    <div className="empty-state" role="status">
      {icon && <div className="empty-state-icon">{icon}</div>}
      <div>
        <div style={{ fontWeight: '600', color: 'var(--text-secondary)', fontSize: '14px' }}>
          {title}
        </div>
        {description && (
          <div style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '4px' }}>
            {description}
          </div>
        )}
      </div>
    </div>
  );
}

interface ErrorAlertProps {
  message: string;
  onRetry?: () => void;
}

export function ErrorAlert({ message, onRetry }: ErrorAlertProps) {
  return (
    <div className="alert alert-error" role="alert">
      <span style={{ flex: 1 }}>{message}</span>
      {onRetry && (
        <button onClick={onRetry} className="btn btn-ghost btn-sm">
          Retry
        </button>
      )}
    </div>
  );
}

interface PaginationProps {
  page: number;
  totalPages: number;
  total: number;
  limit: number;
  onPageChange: (page: number) => void;
}

export function Pagination({
  page,
  totalPages,
  total,
  limit,
  onPageChange,
}: PaginationProps) {
  const from = Math.min((page - 1) * limit + 1, total);
  const to = Math.min(page * limit, total);

  return (
    <div className="pagination">
      <span className="pagination-info">
        Showing {from}–{to} of {total.toLocaleString()} results
      </span>
      <button
        className="btn btn-secondary btn-sm"
        onClick={() => onPageChange(page - 1)}
        disabled={page <= 1}
        aria-label="Previous page"
      >
        ← Prev
      </button>
      <span
        style={{
          fontSize: '12px',
          color: 'var(--text-secondary)',
          padding: '0 4px',
          minWidth: '80px',
          textAlign: 'center',
        }}
      >
        {page} / {totalPages}
      </span>
      <button
        className="btn btn-secondary btn-sm"
        onClick={() => onPageChange(page + 1)}
        disabled={page >= totalPages}
        aria-label="Next page"
      >
        Next →
      </button>
    </div>
  );
}

interface ConfirmDialogProps {
  title: string;
  message: string;
  confirmLabel?: string;
  cancelLabel?: string;
  onConfirm: () => void;
  onCancel: () => void;
  variant?: 'danger' | 'primary';
  isLoading?: boolean;
}

export function ConfirmDialog({
  title,
  message,
  confirmLabel = 'Confirm',
  cancelLabel = 'Cancel',
  onConfirm,
  onCancel,
  variant = 'primary',
  isLoading,
}: ConfirmDialogProps) {
  return (
    <div className="dialog-overlay" role="dialog" aria-modal="true" aria-labelledby="dialog-title">
      <div className="dialog-box">
        <h3
          id="dialog-title"
          style={{ fontSize: '16px', fontWeight: '700', marginBottom: '8px' }}
        >
          {title}
        </h3>
        <p style={{ fontSize: '13px', color: 'var(--text-secondary)', marginBottom: '20px' }}>
          {message}
        </p>
        <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end' }}>
          <button className="btn btn-secondary" onClick={onCancel} disabled={isLoading}>
            {cancelLabel}
          </button>
          <button
            className={`btn ${variant === 'danger' ? 'btn-danger' : 'btn-primary'}`}
            onClick={onConfirm}
            disabled={isLoading}
          >
            {isLoading ? 'Processing...' : confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}

interface PageHeaderProps {
  title: string;
  description?: string;
  actions?: React.ReactNode;
}

export function PageHeader({ title, description, actions }: PageHeaderProps) {
  return (
    <div className="page-header">
      <div>
        <h1 className="page-title">{title}</h1>
        {description && <p className="page-description">{description}</p>}
      </div>
      {actions && <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>{actions}</div>}
    </div>
  );
}
