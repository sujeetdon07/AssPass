import { describe, it, expect } from 'vitest';
import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import { GetNearbyPostsDto } from '../../src/modules/nearby/dto/get-nearby-posts.dto.js';
import { PostCategory } from '../../src/modules/feed/entities/post.entity.js';
import { formatPrivacySafeDistance } from '../../src/modules/nearby/dto/nearby-post-response.dto.js';

describe('GetNearbyPostsDto Validation', () => {
  it('passes validation with valid coordinates and default radius', async () => {
    const dto = plainToInstance(GetNearbyPostsDto, {
      latitude: 12.9784,
      longitude: 77.6408,
    });
    const errors = await validate(dto);
    expect(errors.length).toBe(0);
    expect(dto.radius).toBe(5);
    expect(dto.limit).toBe(20);
  });

  it('passes validation with explicit allowed radius and category', async () => {
    const dto = plainToInstance(GetNearbyPostsDto, {
      latitude: 12.9784,
      longitude: 77.6408,
      radius: 10,
      category: PostCategory.ALERT,
      limit: 15,
      cursor: 'bWFsaWNpb3Vz',
    });
    const errors = await validate(dto);
    expect(errors.length).toBe(0);
  });

  it('rejects missing latitude or longitude', async () => {
    const dto = plainToInstance(GetNearbyPostsDto, {});
    const errors = await validate(dto);
    expect(errors.length).toBeGreaterThanOrEqual(2);
  });

  it('rejects out-of-bounds latitude (< -90 or > 90)', async () => {
    const dtoTooHigh = plainToInstance(GetNearbyPostsDto, {
      latitude: 91,
      longitude: 77.6408,
    });
    const errorsHigh = await validate(dtoTooHigh);
    expect(errorsHigh.length).toBeGreaterThan(0);

    const dtoTooLow = plainToInstance(GetNearbyPostsDto, {
      latitude: -91,
      longitude: 77.6408,
    });
    const errorsLow = await validate(dtoTooLow);
    expect(errorsLow.length).toBeGreaterThan(0);
  });

  it('rejects out-of-bounds longitude (< -180 or > 180)', async () => {
    const dtoTooHigh = plainToInstance(GetNearbyPostsDto, {
      latitude: 12.9784,
      longitude: 181,
    });
    const errorsHigh = await validate(dtoTooHigh);
    expect(errorsHigh.length).toBeGreaterThan(0);

    const dtoTooLow = plainToInstance(GetNearbyPostsDto, {
      latitude: 12.9784,
      longitude: -181,
    });
    const errorsLow = await validate(dtoTooLow);
    expect(errorsLow.length).toBeGreaterThan(0);
  });

  it('rejects radius less than 1 km or exceeding 20 km', async () => {
    const dtoTooSmall = plainToInstance(GetNearbyPostsDto, {
      latitude: 12.9784,
      longitude: 77.6408,
      radius: 0,
    });
    const errorsSmall = await validate(dtoTooSmall);
    expect(errorsSmall.length).toBeGreaterThan(0);

    const dtoTooLarge = plainToInstance(GetNearbyPostsDto, {
      latitude: 12.9784,
      longitude: 77.6408,
      radius: 25,
    });
    const errorsLarge = await validate(dtoTooLarge);
    expect(errorsLarge.length).toBeGreaterThan(0);
  });

  it('rejects page limit exceeding 50', async () => {
    const dto = plainToInstance(GetNearbyPostsDto, {
      latitude: 12.9784,
      longitude: 77.6408,
      limit: 100,
    });
    const errors = await validate(dto);
    expect(errors.length).toBeGreaterThan(0);
  });
});

describe('formatPrivacySafeDistance', () => {
  it('formats distances under 100m as Nearby', () => {
    expect(formatPrivacySafeDistance(45).distanceText).toBe('Nearby');
    expect(formatPrivacySafeDistance(99).distanceText).toBe('Nearby');
  });

  it('formats distances 100m - 999m as rounded meters', () => {
    const d420 = formatPrivacySafeDistance(420);
    expect(d420.distanceText).toBe('400 m away');
    expect(d420.distanceMetersRounded).toBe(400);

    const d870 = formatPrivacySafeDistance(870);
    expect(d870.distanceText).toBe('850 m away');
    expect(d870.distanceMetersRounded).toBe(850);
  });

  it('formats distances 1km - 9.9km with one decimal place', () => {
    const d1240 = formatPrivacySafeDistance(1240);
    expect(d1240.distanceText).toBe('1.2 km away');

    const d5890 = formatPrivacySafeDistance(5890);
    expect(d5890.distanceText).toBe('5.9 km away');
  });

  it('formats distances 10km and above as rounded integer kilometers', () => {
    const d14200 = formatPrivacySafeDistance(14200);
    expect(d14200.distanceText).toBe('14 km away');
  });
});
