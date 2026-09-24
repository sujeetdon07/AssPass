import { Injectable } from '@nestjs/common';
import {
  INDIAN_LOCALITIES_FIXTURE,
  type LocalityItem,
} from './fixtures/indian-localities.fixture.js';

@Injectable()
export class LocalitiesService {
  /**
   * Search localities by city name, locality name, or state.
   */
  search(query?: string, limit = 10): LocalityItem[] {
    if (!query || query.trim().length === 0) {
      return this.getPopular(limit);
    }

    const q = query.trim().toLowerCase();
    const results = INDIAN_LOCALITIES_FIXTURE.filter((loc) => {
      return (
        loc.locality.toLowerCase().includes(q) ||
        loc.city.toLowerCase().includes(q) ||
        loc.state.toLowerCase().includes(q) ||
        (loc.postalCode && loc.postalCode.includes(q))
      );
    });

    return results.slice(0, limit);
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
