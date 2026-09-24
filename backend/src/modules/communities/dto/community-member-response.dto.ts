import {
  CommunityRole,
  CommunityMemberStatus,
} from '../entities/community-member.entity.js';

export interface CommunityMemberProfile {
  id: string;
  displayName: string | null;
  avatarUrl: string | null;
  locality: string | null;
  city: string | null;
}

export interface CommunityMemberResponse {
  id: string;
  communityId: string;
  userId: string;
  role: CommunityRole;
  status: CommunityMemberStatus;
  user: CommunityMemberProfile;
  joinedAt: Date;
}

export interface PaginatedCommunityMembersResponse {
  members: CommunityMemberResponse[];
  nextCursor?: string;
  hasMore: boolean;
  total?: number;
}
