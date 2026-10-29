-- ============================================================
-- LABS 2-3: ETL Pipeline and Data Cleaning
-- PostgreSQL 16+
-- Depends on: lab1_fisheries_star_schema.sql (dw schema must exist)
-- ============================================================

SET search_path = dw, public;

-- ============================================================
-- STEP 1: Staging schema + raw table
-- ============================================================
DROP SCHEMA IF EXISTS stg CASCADE;
CREATE SCHEMA stg;

CREATE TABLE stg.landings_raw (
    landing_date    TEXT,
    port_code       TEXT,
    vessel_code     TEXT,
    species_name    TEXT,
    quantity_kg     TEXT,
    price_per_kg    TEXT,
    trip_days       TEXT
);

-- Load the CSV (run from psql):
-- \copy stg.landings_raw FROM 'landings_2026.csv' CSV HEADER;


-- ============================================================
-- STEP 2: Data Profiling
-- ============================================================

-- 2a. Row count
SELECT COUNT(*) AS total_rows FROM stg.landings_raw;

-- 2b. Missing values per column
SELECT
    COUNT(*) FILTER (WHERE landing_date  IS NULL OR landing_date  = '') AS missing_date,
    COUNT(*) FILTER (WHERE port_code     IS NULL OR port_code     = '') AS missing_port,
    COUNT(*) FILTER (WHERE vessel_code   IS NULL OR vessel_code   = '') AS missing_vessel,
    COUNT(*) FILTER (WHERE species_name  IS NULL OR species_name  = '') AS missing_species,
    COUNT(*) FILTER (WHERE quantity_kg   IS NULL OR quantity_kg   = '') AS missing_qty,
    COUNT(*) FILTER (WHERE price_per_kg  IS NULL OR price_per_kg  = '') AS missing_price,
    COUNT(*) FILTER (WHERE trip_days     IS NULL OR trip_days     = '') AS missing_days
FROM stg.landings_raw;

-- 2c. Duplicate rows
SELECT landing_date, port_code, vessel_code, species_name,
       quantity_kg, price_per_kg, trip_days,
       COUNT(*) AS cnt
FROM stg.landings_raw
GROUP BY landing_date, port_code, vessel_code, species_name,
         quantity_kg, price_per_kg, trip_days
HAVING COUNT(*) > 1;

-- 2d. Outliers (quantity > 10000 kg or price > 2000)
SELECT *
FROM stg.landings_raw
WHERE quantity_kg ~ '^\d+(\.\d+)?$'
  AND (quantity_kg::NUMERIC > 10000 OR price_per_kg::NUMERIC > 2000);

-- 2e. Distinct raw species names (to spot inconsistencies)
SELECT TRIM(LOWER(species_name)) AS raw_species, COUNT(*) AS cnt
FROM stg.landings_raw
WHERE species_name IS NOT NULL AND species_name <> ''
GROUP BY 1
ORDER BY 1;


-- ============================================================
-- STEP 3: Species Mapping Table
-- ============================================================
CREATE TABLE stg.species_map (
    raw_name    TEXT PRIMARY KEY,
    species_code VARCHAR(10) NOT NULL
);

INSERT INTO stg.species_map (raw_name, species_code) VALUES
-- Yellowfin Tuna variants
('yellowfin tuna',  'SPC001'), ('yellow fin tuna', 'SPC001'),
('yf tuna',         'SPC001'), ('yellowfin',       'SPC001'),
-- Skipjack Tuna variants
('skipjack tuna',   'SPC002'), ('skipjack',        'SPC002'),
('skip jack tuna',  'SPC002'),
-- Milkfish variants
('milkfish',        'SPC003'), ('milk fish',       'SPC003'),
('bangus',          'SPC003'),
-- Tilapia variants
('tilapia',         'SPC004'), ('tilapya',         'SPC004'),
-- Blue Marlin variants
('blue marlin',     'SPC005'), ('bluemarlin',      'SPC005'),
('blue-marlin',     'SPC005'),
-- Grouper variants
('grouper',         'SPC006'), ('lapu-lapu',       'SPC006'),
-- Squid variants
('squid',           'SPC007'), ('pusit',           'SPC007'),
-- Shrimp variants
('shrimp',          'SPC008'), ('hipon',           'SPC008'),
-- Sardine variants
('sardine',         'SPC009'), ('sardines',        'SPC009'),
-- Mackerel variants
('mackerel',        'SPC010'), ('hasa-hasa',       'SPC010');


-- ============================================================
-- STEP 4: Cleaned staging table
-- ============================================================
DROP TABLE IF EXISTS stg.landings_clean;

CREATE TABLE stg.landings_clean AS
WITH deduped AS (
    -- Remove exact duplicates, keep one
    SELECT DISTINCT
        landing_date, port_code, vessel_code, species_name,
        quantity_kg, price_per_kg, trip_days
    FROM stg.landings_raw
),
typed AS (
    SELECT
        landing_date::DATE                          AS landing_date,
        TRIM(port_code)                             AS port_code,
        TRIM(vessel_code)                           AS vessel_code,
        TRIM(LOWER(species_name))                   AS species_name_raw,
        quantity_kg::NUMERIC                        AS quantity_kg,
        price_per_kg::NUMERIC                       AS price_per_kg,
        trip_days::SMALLINT                         AS trip_days
    FROM deduped
    WHERE
        -- Reject rows with any NULL/empty critical field
        landing_date  IS NOT NULL AND landing_date  <> ''
        AND port_code    IS NOT NULL AND port_code    <> ''
        AND vessel_code  IS NOT NULL AND vessel_code  <> ''
        AND species_name IS NOT NULL AND species_name <> ''
        AND quantity_kg  IS NOT NULL AND quantity_kg  <> ''
        AND price_per_kg IS NOT NULL AND price_per_kg <> ''
        AND trip_days    IS NOT NULL AND trip_days    <> ''
        -- Reject non-numeric measures
        AND quantity_kg  ~ '^\d+(\.\d+)?$'
        AND price_per_kg ~ '^\d+(\.\d+)?$'
        AND trip_days    ~ '^\d+$'
)
SELECT
    t.landing_date,
    t.port_code,
    t.vessel_code,
    sm.species_code,
    t.quantity_kg,
    t.price_per_kg,
    t.trip_days
FROM typed t
JOIN stg.species_map sm ON sm.raw_name = t.species_name_raw
WHERE
    -- Reject outliers
    t.quantity_kg  BETWEEN 1 AND 10000
    AND t.price_per_kg BETWEEN 1 AND 2000
    AND t.trip_days    BETWEEN 1 AND 30;

-- Verify clean row count
SELECT COUNT(*) AS clean_rows FROM stg.landings_clean;


-- ============================================================
-- STEP 5: Load Dimensions (upserts) + Facts (INSERT...SELECT)
-- ============================================================

-- 5a. Upsert dim_port (ports already exist from Lab 1; no-op if unchanged)
INSERT INTO dw.dim_port (port_code, port_name, municipality, province, region, cooperative)
SELECT DISTINCT
    lc.port_code,
    lc.port_code  AS port_name,       -- placeholder if new port
    'Unknown'     AS municipality,
    'Unknown'     AS province,
    'Unknown'     AS region,
    'Unknown'     AS cooperative
FROM stg.landings_clean lc
WHERE NOT EXISTS (
    SELECT 1 FROM dw.dim_port dp WHERE dp.port_code = lc.port_code
);

-- 5b. Upsert dim_vessel (current record only; new vessels get inserted)
INSERT INTO dw.dim_vessel (vessel_code, vessel_name, vessel_type, gross_tonnage,
                           owner_name, cooperative, effective_date, expiry_date, is_current)
SELECT DISTINCT
    lc.vessel_code,
    lc.vessel_code AS vessel_name,
    'Unknown'      AS vessel_type,
    0              AS gross_tonnage,
    'Unknown'      AS owner_name,
    'Unknown'      AS cooperative,
    '2026-01-01'   AS effective_date,
    '9999-12-31'   AS expiry_date,
    TRUE           AS is_current
FROM stg.landings_clean lc
WHERE NOT EXISTS (
    SELECT 1 FROM dw.dim_vessel dv
    WHERE dv.vessel_code = lc.vessel_code AND dv.is_current = TRUE
);

-- 5c. Insert fact rows (only for dates that exist in dim_date)
INSERT INTO dw.fact_landing (date_key, port_key, species_key, vessel_key,
                              quantity_kg, price_per_kg, trip_days)
SELECT
    dd.date_key,
    dp.port_key,
    ds.species_key,
    dv.vessel_key,
    lc.quantity_kg,
    lc.price_per_kg,
    lc.trip_days
FROM stg.landings_clean lc
JOIN dw.dim_date    dd ON dd.full_date   = lc.landing_date
JOIN dw.dim_port    dp ON dp.port_code   = lc.port_code
JOIN dw.dim_species ds ON ds.species_code = lc.species_code
JOIN dw.dim_vessel  dv ON dv.vessel_code  = lc.vessel_code AND dv.is_current = TRUE;

-- Verify fact count after load
SELECT COUNT(*) AS total_facts FROM dw.fact_landing;


-- ============================================================
-- STEP 6: Rejection log (rows that did NOT make it to clean)
-- ============================================================
CREATE TABLE stg.landings_rejected AS
SELECT r.*, 'DUPLICATE or MISSING or OUTLIER or UNMAPPED_SPECIES' AS reject_reason
FROM stg.landings_raw r
WHERE NOT EXISTS (
    SELECT 1 FROM stg.landings_clean lc
    WHERE lc.landing_date::TEXT = r.landing_date
      AND lc.port_code          = r.port_code
      AND lc.vessel_code        = r.vessel_code
      AND lc.quantity_kg::TEXT  = r.quantity_kg
      AND lc.price_per_kg::TEXT = r.price_per_kg
      AND lc.trip_days::TEXT    = r.trip_days
);

SELECT COUNT(*) AS rejected_rows FROM stg.landings_rejected;
