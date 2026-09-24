import { describe, it, expect, beforeEach } from 'vitest';
import { LocalitiesService } from '../../src/modules/localities/localities.service.js';

describe('LocalitiesService', () => {
  let service: LocalitiesService;

  beforeEach(() => {
    service = new LocalitiesService();
  });

  it('returns popular localities when query is empty', () => {
    const popular = service.getPopular(5);
    expect(popular).toHaveLength(5);
    expect(popular[0]?.city).toBeDefined();
  });

  it('searches localities by query matching city or locality', () => {
    const results = service.search('Indiranagar');
    expect(results.length).toBeGreaterThan(0);
    expect(results[0]?.locality).toBe('Indiranagar');
    expect(results[0]?.city).toBe('Bengaluru');

    const meerutResults = service.search('Meerut');
    expect(meerutResults.length).toBeGreaterThan(0);
    expect(meerutResults[0]?.city).toBe('Meerut');
  });
});
