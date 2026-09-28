import { User } from '../../users/entities/user.entity.js';

export interface PublicProfileProjection {
  id: string;
  username: string | null;
  displayName: string;
  avatarUrl: string | null;
  locality: string | null;
  city: string | null;
}

export function toPublicProfile(user: User | null | undefined): PublicProfileProjection {
  if (!user) {
    return {
      id: '',
      username: null,
      displayName: 'Neighbor',
      avatarUrl: null,
      locality: null,
      city: null,
    };
  }

  return {
    id: user.id,
    username: user.username ?? null,
    displayName: user.displayName || 'Neighbor',
    avatarUrl: user.avatarUrl ?? null,
    locality: user.locality ?? null,
    city: user.city ?? null,
  };
}
