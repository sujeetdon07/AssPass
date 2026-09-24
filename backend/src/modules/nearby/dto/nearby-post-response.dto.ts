import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { PostCategory } from '../../feed/entities/post.entity.js';

export class AuthorSummaryDto {
  @ApiProperty({ description: 'User ID' })
  id!: string;

  @ApiPropertyOptional({ description: 'Display name' })
  displayName!: string | null;

  @ApiPropertyOptional({ description: 'Avatar image URL' })
  avatarUrl!: string | null;

  @ApiPropertyOptional({ description: 'Locality name' })
  locality!: string | null;

  @ApiPropertyOptional({ description: 'City name' })
  city!: string | null;
}

/**
 * Formats raw distance in meters into a privacy-safe, human-friendly representation.
 * Prevents precision triangulation attacks while providing useful local context.
 */
export function formatPrivacySafeDistance(meters: number): {
  distanceText: string;
  distanceMetersRounded: number;
} {
  if (meters < 100) {
    return {
      distanceText: 'Nearby',
      distanceMetersRounded: 100,
    };
  } else if (meters < 1000) {
    const rounded = Math.round(meters / 50) * 50;
    return {
      distanceText: `${rounded} m away`,
      distanceMetersRounded: rounded,
    };
  } else if (meters < 10000) {
    const km = (meters / 1000).toFixed(1);
    return {
      distanceText: `${km} km away`,
      distanceMetersRounded: Math.round(meters / 100) * 100,
    };
  } else {
    const km = Math.round(meters / 1000);
    return {
      distanceText: `${km} km away`,
      distanceMetersRounded: km * 1000,
    };
  }
}

export class NearbyPostResponse {
  @ApiProperty({ description: 'Post ID' })
  id!: string;

  @ApiProperty({ description: 'Author ID' })
  authorId!: string;

  @ApiProperty({ type: AuthorSummaryDto, description: 'Public author profile summary' })
  author!: AuthorSummaryDto;

  @ApiProperty({ description: 'Post text content' })
  content!: string;

  @ApiProperty({ enum: PostCategory })
  category!: PostCategory;

  @ApiPropertyOptional({ description: 'Locality name' })
  locality?: string | null;

  @ApiPropertyOptional({ description: 'Neighborhood / sub-area name' })
  neighborhood?: string | null;

  @ApiPropertyOptional({ description: 'City name' })
  city?: string | null;

  @ApiPropertyOptional({ description: 'State / Province name' })
  state?: string | null;

  @ApiProperty({ description: 'Country code', default: 'IN' })
  countryCode!: string;

  @ApiProperty({ description: 'Total likes count' })
  likeCount!: number;

  @ApiProperty({ description: 'Total comments count' })
  commentCount!: number;

  @ApiProperty({ description: 'Whether the current authenticated user liked this post' })
  currentUserLiked!: boolean;

  @ApiProperty({ description: 'Whether the post was authored by current authenticated user' })
  isOwnPost!: boolean;

  @ApiProperty({
    description: 'Privacy-safe distance description (e.g. "Nearby", "450 m away", "1.2 km away")',
    example: '1.2 km away',
  })
  distance!: string;

  @ApiProperty({
    description: 'Privacy-safe rounded distance band in meters',
    example: 1200,
  })
  distanceMeters!: number;

  @ApiPropertyOptional({ description: 'Community ID if scoped to a community' })
  communityId?: string | null;

  @ApiPropertyOptional({ description: 'Community summary if scoped to a community' })
  community?: { id: string; name: string; slug: string } | null;

  @ApiProperty()
  createdAt!: Date;

  @ApiProperty()
  updatedAt!: Date;
}

export class PaginatedNearbyResponse {
  @ApiProperty({ type: [NearbyPostResponse] })
  items!: NearbyPostResponse[];

  @ApiPropertyOptional({ description: 'Cursor token for the next page' })
  nextCursor?: string | null;

  @ApiProperty({ description: 'Whether additional pages are available' })
  hasMore!: boolean;

  @ApiProperty({ description: 'Radius in kilometers used for this query' })
  radiusKm!: number;
}
