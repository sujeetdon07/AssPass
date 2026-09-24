export interface Coordinates {
  longitude: number;
  latitude: number;
}

/**
 * Known public centroids for Indian metropolitan localities.
 * Represents safe locality-level discovery centroids, NOT user residential locations.
 */
const LOCALITY_CENTROIDS: Record<string, Coordinates> = {
  // Bengaluru
  'indiranagar': { longitude: 77.6408, latitude: 12.9784 },
  'koramangala': { longitude: 77.6245, latitude: 12.9352 },
  'hsr layout': { longitude: 77.6446, latitude: 12.9121 },
  'hsr': { longitude: 77.6446, latitude: 12.9121 },
  'whitefield': { longitude: 77.7500, latitude: 12.9698 },

  // Delhi NCR
  'connaught place': { longitude: 77.2167, latitude: 28.6315 },
  'hauz khas': { longitude: 77.2001, latitude: 28.5494 },
  'saket': { longitude: 77.2177, latitude: 28.5244 },
  'dlf phase 5': { longitude: 77.0945, latitude: 28.4357 },
  'sector 62': { longitude: 77.3649, latitude: 28.6258 },

  // Mumbai
  'bandra west': { longitude: 72.8295, latitude: 19.0596 },
  'bandra': { longitude: 72.8295, latitude: 19.0596 },
  'andheri west': { longitude: 72.8277, latitude: 19.1363 },
  'andheri': { longitude: 72.8277, latitude: 19.1363 },
  'colaba': { longitude: 72.8147, latitude: 18.9067 },

  // Pune
  'koregaon park': { longitude: 73.8940, latitude: 18.5362 },
  'kothrud': { longitude: 73.8077, latitude: 18.5074 },

  // Meerut
  'shastri nagar': { longitude: 77.7167, latitude: 28.9667 },
  'civil lines': { longitude: 77.7119, latitude: 28.9950 },

  // Hyderabad
  'banjara hills': { longitude: 78.4350, latitude: 17.4156 },
  'jubilee hills': { longitude: 78.4073, latitude: 17.4319 },

  // Jaipur
  'malviya nagar': { longitude: 75.8193, latitude: 26.8530 },
  'vaishali nagar': { longitude: 75.7433, latitude: 26.9124 },
};

const CITY_CENTROIDS: Record<string, Coordinates> = {
  'bengaluru': { longitude: 77.5946, latitude: 12.9716 },
  'bangalore': { longitude: 77.5946, latitude: 12.9716 },
  'new delhi': { longitude: 77.2090, latitude: 28.6139 },
  'delhi': { longitude: 77.2090, latitude: 28.6139 },
  'gurugram': { longitude: 77.0266, latitude: 28.4595 },
  'noida': { longitude: 77.3910, latitude: 28.5355 },
  'mumbai': { longitude: 72.8777, latitude: 19.0760 },
  'pune': { longitude: 73.8567, latitude: 18.5204 },
  'meerut': { longitude: 77.7064, latitude: 28.9845 },
  'hyderabad': { longitude: 78.4867, latitude: 17.3850 },
  'jaipur': { longitude: 75.7873, latitude: 26.9124 },
};

/**
 * Resolves a safe public geographic centroid for a given locality and city.
 * Always returns a non-null centroid (defaulting to Bengaluru center if unrecognized).
 */
export function getLocalityCentroid(
  locality?: string | null,
  city?: string | null,
): Coordinates {
  if (locality) {
    const key = locality.trim().toLowerCase();
    for (const [locKey, coords] of Object.entries(LOCALITY_CENTROIDS)) {
      if (key.includes(locKey) || locKey.includes(key)) {
        return coords;
      }
    }
  }

  if (city) {
    const key = city.trim().toLowerCase();
    for (const [cityKey, coords] of Object.entries(CITY_CENTROIDS)) {
      if (key.includes(cityKey) || cityKey.includes(key)) {
        return coords;
      }
    }
  }

  // Default Indian metropolis fallback (Bengaluru)
  return { longitude: 77.5946, latitude: 12.9716 };
}
