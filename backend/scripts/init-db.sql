-- Aaspaas Database Initialization Script
-- Run automatically by PostgreSQL on first container startup.

-- Enable PostGIS extension.
-- This provides geographic data types (geometry, geography) and functions
-- like ST_DWithin, ST_MakePoint, ST_SetSRID used for location-based queries.
CREATE EXTENSION IF NOT EXISTS postgis;

-- Enable pg_trgm for future full-text search optimization.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Enable uuid-ossp for UUID generation.
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Verify PostGIS is enabled.
-- This will appear in the Docker startup logs.
DO $$
BEGIN
  RAISE NOTICE 'PostGIS version: %', PostGIS_Version();
END
$$;
