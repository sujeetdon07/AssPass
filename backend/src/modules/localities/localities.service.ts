import { Injectable, Logger } from '@nestjs/common';
import {
  INDIAN_LOCALITIES_FIXTURE,
  type LocalityItem,
} from './fixtures/indian-localities.fixture.js';

interface NominatimAddress {
  suburb?: string;
  neighbourhood?: string;
  residential?: string;
  quarter?: string;
  road?: string;
  city?: string;
  town?: string;
  village?: string;
  municipality?: string;
  county?: string;
  state_district?: string;
  state?: string;
  postcode?: string;
  country_code?: string;
}

interface NominatimPlace {
  place_id?: number;
  osm_id?: number;
  osm_type?: string;
  name?: string;
  display_name?: string;
  address?: NominatimAddress;
}

@Injectable()
export class LocalitiesService {
  private readonly logger = new Logger(LocalitiesService.name);
  private readonly searchCache = new Map<string, { timestamp: number; data: LocalityItem[] }>();
  private readonly CACHE_TTL_MS = 10 * 60 * 1000; // 10 minutes

  /**
   * Search localities by city name, locality name, or state.
   * Merges local curated fixtures with live OpenStreetMap Nominatim geocoding.
   */
  async search(query?: string, limit = 10): Promise<LocalityItem[]> {
    if (!query || query.trim().length === 0) {
      return this.getPopular(limit);
    }

    const q = query.trim();
    const cacheKey = `${q.toLowerCase()}:${limit}`;
    const cached = this.searchCache.get(cacheKey);
    if (cached && Date.now() - cached.timestamp < this.CACHE_TTL_MS) {
      return cached.data;
    }

    // 1. Search local fixtures
    const qLower = q.toLowerCase();
    const fixtureMatches = INDIAN_LOCALITIES_FIXTURE.filter((loc) => {
      return (
        loc.locality.toLowerCase().includes(qLower) ||
        loc.city.toLowerCase().includes(qLower) ||
        loc.state.toLowerCase().includes(qLower) ||
        (loc.postalCode && loc.postalCode.includes(qLower))
      );
    });

    const results: LocalityItem[] = [...fixtureMatches];
    const seenKeys = new Set(
      fixtureMatches.map((item) => `${item.locality.toLowerCase().trim()}|${item.city.toLowerCase().trim()}`),
    );

    // 2. Fetch live results from Nominatim if needed
    try {
      const liveItems = await this.queryNominatim(q, limit);
      for (const item of liveItems) {
        const key = `${item.locality.toLowerCase().trim()}|${item.city.toLowerCase().trim()}`;
        if (!seenKeys.has(key)) {
          seenKeys.add(key);
          results.push(item);
        }
      }
    } catch (err) {
      this.logger.warn(`Nominatim search failed for query "${q}": ${(err as Error).message}`);
    }

    const finalResults = results.slice(0, limit);
    this.searchCache.set(cacheKey, { timestamp: Date.now(), data: finalResults });
    return finalResults;
  }

  /**
   * Reverse geocode GPS coordinates to an Indian locality.
   */
  async reverseGeocode(lat: number, lon: number): Promise<LocalityItem | null> {
    if (isNaN(lat) || isNaN(lon)) {
      return null;
    }

    try {
      const url = `https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lon}&format=json&addressdetails=1`;
      const response = await fetch(url, {
        headers: {
          'User-Agent': 'Aaspaas-App/1.0 (contact@aaspaas.in)',
          Accept: 'application/json',
        },
        signal: AbortSignal.timeout(3500),
      });

      if (!response.ok) {
        this.logger.warn(`Nominatim reverse HTTP ${response.status} for lat=${lat}, lon=${lon}`);
        return null;
      }

      const data = (await response.json()) as NominatimPlace;
      return this.mapNominatimPlace(data);
    } catch (err) {
      this.logger.warn(`Nominatim reverse geocode failed: ${(err as Error).message}`);
      return null;
    }
  }

  /**
   * Query OpenStreetMap Nominatim for search term.
   */
  private async queryNominatim(query: string, limit: number): Promise<LocalityItem[]> {
    const url = `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(
      query,
    )}&format=json&addressdetails=1&countrycodes=in&limit=${limit}`;

    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Aaspaas-App/1.0 (contact@aaspaas.in)',
        Accept: 'application/json',
      },
      signal: AbortSignal.timeout(3500),
    });

    if (!response.ok) {
      return [];
    }

    const data = (await response.json()) as NominatimPlace[];
    if (!Array.isArray(data)) {
      return [];
    }

    const items: LocalityItem[] = [];
    for (const place of data) {
      const item = this.mapNominatimPlace(place);
      if (item) {
        items.push(item);
      }
    }
    return items;
  }

  /**
   * Map raw Nominatim response into LocalityItem.
   */
  private mapNominatimPlace(place: NominatimPlace): LocalityItem | null {
    const addr = place.address || {};
    const city =
      addr.city ||
      addr.town ||
      addr.municipality ||
      addr.village ||
      addr.county ||
      addr.state_district ||
      '';
    const state = addr.state || addr.state_district || '';
    const district = addr.state_district || addr.county || city;

    let locality =
      place.name ||
      addr.residential ||
      addr.suburb ||
      addr.neighbourhood ||
      addr.quarter ||
      addr.road ||
      city;

    if (!locality && !city) {
      return null;
    }
    if (!locality) {
      locality = city;
    }

    const id = `osm-${place.osm_type || 'p'}-${place.osm_id || place.place_id || Buffer.from(locality + city).toString('hex').slice(0, 10)}`;

    return {
      id,
      countryCode: (addr.country_code || 'IN').toUpperCase(),
      state,
      district,
      city: city || locality,
      locality,
      postalCode: addr.postcode,
    };
  }

  /**
   * Returns a list of popular localities across Indian metro cities.
   */
  getPopular(limit = 10): LocalityItem[] {
    return INDIAN_LOCALITIES_FIXTURE.slice(0, limit);
  }

  /**
   * Look up a locality item by fixture ID.
   */
  findById(id: string): LocalityItem | null {
    return INDIAN_LOCALITIES_FIXTURE.find((loc) => loc.id === id) ?? null;
  }
}
