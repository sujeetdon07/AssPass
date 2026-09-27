import { User } from '../../users/entities/user.entity.js';

export interface PublicProfileProjection {
  id: string;
  displayName: string;
  avatarUrl: string | null;
  locality: string | null;
  city: string | null;
}

export function toPublicProfile(user: User | null | undefined): PublicProfileProjection {
  if (!user) {
    return {
      id: '',
      displayName: 'Neighbor',
      avatarUrl: null,
      locality: null,
      city: null,
    };
  }

  return {
    id: user.id,
    displayName: user.displayName || 'Neighbor',
    avatarUrl: user.avatarUrl ?? null,
    locality: user.locality ?? null,
    city: user.city ?? null,
  };
}
