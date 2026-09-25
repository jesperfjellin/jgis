-- Runs after every OSM import. osm2pgsql already creates a GiST index on each
-- geometry column and sorts rows by geometry; this adds attribute indexes used
-- by scale-dependent filters and refreshes planner statistics.

-- Primary keys: GeoServer needs them for stable feature IDs and for paging
-- (WFS startIndex, OGC API Features). Tables with a fid column (the area tables,
-- see osm.lua) use it; the others use the osm2pgsql id column. Each OSM object is
-- stored at most once per table, so these columns are unique.
DO $$
DECLARE
    t record;
BEGIN
    FOR t IN
        SELECT c.table_name,
               (array_agg(c.column_name ORDER BY c.column_name = 'fid' DESC))[1] AS column_name
        FROM information_schema.columns c
        WHERE c.table_schema = 'osm'
          AND c.column_name IN ('fid', 'node_id', 'way_id', 'area_id', 'relation_id')
          AND NOT EXISTS (SELECT 1 FROM information_schema.table_constraints tc
                          WHERE tc.table_schema = 'osm' AND tc.table_name = c.table_name
                            AND tc.constraint_type = 'PRIMARY KEY')
        GROUP BY c.table_name
    LOOP
        EXECUTE format('ALTER TABLE osm.%I ADD PRIMARY KEY (%I)', t.table_name, t.column_name);
    END LOOP;
END $$;

CREATE INDEX IF NOT EXISTS roads_rank_idx ON osm.roads (rank);
CREATE INDEX IF NOT EXISTS buildings_area_idx ON osm.buildings (area);
CREATE INDEX IF NOT EXISTS landcover_area_idx ON osm.landcover (area);
CREATE INDEX IF NOT EXISTS water_area_idx ON osm.water (area);
CREATE INDEX IF NOT EXISTS places_class_idx ON osm.places (class);
CREATE INDEX IF NOT EXISTS boundaries_level_idx ON osm.boundaries (admin_level);

GRANT SELECT ON ALL TABLES IN SCHEMA osm TO geoserver;

ANALYZE osm.buildings, osm.roads, osm.railways, osm.waterways, osm.water,
        osm.landcover, osm.pois, osm.places, osm.boundaries;

SELECT relname AS table, n_live_tup AS rows,
       pg_size_pretty(pg_total_relation_size(relid)) AS size
FROM pg_stat_user_tables WHERE schemaname = 'osm' ORDER BY relname;

-- Completion marker, checked by `make up`.
DROP TABLE IF EXISTS public.osm_import;
CREATE TABLE public.osm_import AS SELECT now() AS imported_at, :'source' AS source;
