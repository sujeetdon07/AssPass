import { redirect } from 'next/navigation';
import { getCurrentUser } from '@/lib/api';

export default async function HomePage() {
  const user = await getCurrentUser();

  if (!user) {
    redirect('/login');
  }

  if (user.role !== 'admin' && user.role !== 'moderator') {
    redirect('/unauthorized');
  }

  redirect('/dashboard');
}
