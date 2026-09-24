import {
  CommunityCategory,
  CommunityVisibility,
  CommunityStatus,
} from '../entities/community.entity.js';
import { CommunityRole } from '../entities/community-member.entity.js';

export interface CreatorSummary {
  id: string;
  displayName: string | null;
  avatarUrl: string | null;
}

export interface CommunityResponse {
  id: string;
  name: string;
  slug: string;
  description: string;
  category: CommunityCategory;
  visibility: CommunityVisibility;
  status: CommunityStatus;
  creatorId: string;
  creator?: CreatorSummary;
  countryCode: string;
  state?: string | null;
  district?: string | null;
  city?: string | null;
  locality?: string | null;
  neighborhood?: string | null;
  memberCount: number;
  postCount: number;
  coverImageUrl?: string | null;
  avatarUrl?: string | null;
  currentUserMember: boolean;
  currentUserRole: CommunityRole | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface PaginatedCommunitiesResponse {
  communities: CommunityResponse[];
  nextCursor?: string;
  hasMore: boolean;
  total?: number;
}
