-- ============================================================
-- LAB 1: Build the Fisheries Star Schema
-- PostgreSQL 16+
-- Steps: Schema → dim_date → dimensions → facts → queries → SCD2
-- ============================================================

-- ============================================================
-- STEP 1: Create schema dw
-- ============================================================
DROP SCHEMA IF EXISTS dw CASCADE;
CREATE SCHEMA dw;
SET search_path = dw;


-- ============================================================
-- STEP 2: Create dimension and fact tables
-- ============================================================

-- dim_date
CREATE TABLE dw.dim_date (
    date_key        INT             PRIMARY KEY,   -- YYYYMMDD
    full_date       DATE            NOT NULL UNIQUE,
    day             SMALLINT        NOT NULL,
    month           SMALLINT        NOT NULL,
    month_name      VARCHAR(10)     NOT NULL,
    quarter         SMALLINT        NOT NULL,
    year            SMALLINT        NOT NULL,
    week_of_year    SMALLINT        NOT NULL,
    day_of_week     SMALLINT        NOT NULL,      -- 1=Mon … 7=Sun
    day_name        VARCHAR(10)     NOT NULL,
    is_weekend      BOOLEAN         NOT NULL
);

-- dim_port
CREATE TABLE dw.dim_port (
    port_key        SERIAL          PRIMARY KEY,
    port_code       VARCHAR(10)     NOT NULL UNIQUE,
    port_name       VARCHAR(100)    NOT NULL,
    municipality    VARCHAR(100)    NOT NULL,
    province        VARCHAR(100)    NOT NULL,
    region          VARCHAR(50)     NOT NULL,
    cooperative     VARCHAR(100)    NOT NULL
);

-- dim_species
CREATE TABLE dw.dim_species (
    species_key     SERIAL          PRIMARY KEY,
    species_code    VARCHAR(10)     NOT NULL UNIQUE,
    common_name     VARCHAR(100)    NOT NULL,
    scientific_name VARCHAR(150)    NOT NULL,
    family          VARCHAR(100)    NOT NULL,
    category        VARCHAR(50)     NOT NULL       -- e.g. Pelagic, Demersal
);

-- dim_vessel  (SCD Type 2 — surrogate key + effective dates)
CREATE TABLE dw.dim_vessel (
    vessel_key          SERIAL          PRIMARY KEY,
    vessel_code         VARCHAR(20)     NOT NULL,   -- natural/business key
    vessel_name         VARCHAR(100)    NOT NULL,
    vessel_type         VARCHAR(50)     NOT NULL,
    gross_tonnage       NUMERIC(8,2)    NOT NULL,
    owner_name          VARCHAR(100)    NOT NULL,
    cooperative         VARCHAR(100)    NOT NULL,
    -- SCD Type 2 columns
    effective_date      DATE            NOT NULL,
    expiry_date         DATE            NOT NULL DEFAULT '9999-12-31',
    is_current          BOOLEAN         NOT NULL DEFAULT TRUE
);

-- fact_landing
CREATE TABLE dw.fact_landing (
    landing_key         BIGSERIAL       PRIMARY KEY,
    date_key            INT             NOT NULL REFERENCES dw.dim_date(date_key),
    port_key            INT             NOT NULL REFERENCES dw.dim_port(port_key),
    species_key         INT             NOT NULL REFERENCES dw.dim_species(species_key),
    vessel_key          INT             NOT NULL REFERENCES dw.dim_vessel(vessel_key),
    -- measures
    quantity_kg         NUMERIC(12,2)   NOT NULL CHECK (quantity_kg > 0),
    price_per_kg        NUMERIC(10,2)   NOT NULL CHECK (price_per_kg > 0),
    total_value         NUMERIC(14,2)   GENERATED ALWAYS AS (quantity_kg * price_per_kg) STORED,
    trip_days           SMALLINT        NOT NULL CHECK (trip_days > 0)
);

-- Indexes for star-join performance
CREATE INDEX idx_fact_date    ON dw.fact_landing(date_key);
CREATE INDEX idx_fact_port    ON dw.fact_landing(port_key);
CREATE INDEX idx_fact_species ON dw.fact_landing(species_key);
CREATE INDEX idx_fact_vessel  ON dw.fact_landing(vessel_key);


-- ============================================================
-- STEP 3: Populate dim_date for 2020–2030 using generate_series
-- ============================================================
INSERT INTO dw.dim_date (
    date_key, full_date, day, month, month_name,
    quarter, year, week_of_year, day_of_week, day_name, is_weekend
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT                         AS date_key,
    d::DATE                                              AS full_date,
    EXTRACT(DAY   FROM d)::SMALLINT                     AS day,
    EXTRACT(MONTH FROM d)::SMALLINT                     AS month,
    TO_CHAR(d, 'Month')                                 AS month_name,
    EXTRACT(QUARTER FROM d)::SMALLINT                   AS quarter,
    EXTRACT(YEAR  FROM d)::SMALLINT                     AS year,
    EXTRACT(WEEK  FROM d)::SMALLINT                     AS week_of_year,
    EXTRACT(ISODOW FROM d)::SMALLINT                    AS day_of_week,
    TO_CHAR(d, 'Day')                                   AS day_name,
    EXTRACT(ISODOW FROM d) IN (6, 7)                    AS is_weekend
FROM generate_series(
    '2020-01-01'::DATE,
    '2030-12-31'::DATE,
    '1 day'::INTERVAL
) AS gs(d);


-- ============================================================
-- STEP 4a: Insert sample dimension rows
-- ============================================================

-- dim_port (10 ports)
INSERT INTO dw.dim_port (port_code, port_name, municipality, province, region, cooperative) VALUES
('PRT001', 'General Santos Fish Port',  'General Santos', 'South Cotabato',  'Region XII',  'GenSan Fishers Coop'),
('PRT002', 'Navotas Fish Port',         'Navotas',        'Metro Manila',    'NCR',         'Navotas United Coop'),
('PRT003', 'Iloilo Fish Port',          'Iloilo City',    'Iloilo',          'Region VI',   'Iloilo Fishers Coop'),
('PRT004', 'Davao Fish Port',           'Davao City',     'Davao del Sur',   'Region XI',   'Davao Fishers Coop'),
('PRT005', 'Zamboanga Fish Port',       'Zamboanga City', 'Zamboanga del Sur','Region IX',  'Zamboanga Coop'),
('PRT006', 'Cebu Fish Port',            'Cebu City',      'Cebu',            'Region VII',  'Cebu Fishers Coop'),
('PRT007', 'Lucena Fish Port',          'Lucena City',    'Quezon',          'Region IV-A', 'Lucena Fishers Coop'),
('PRT008', 'Batangas Fish Port',        'Batangas City',  'Batangas',        'Region IV-A', 'Batangas Coop'),
('PRT009', 'Cagayan de Oro Fish Port',  'Cagayan de Oro', 'Misamis Oriental','Region X',   'CDO Fishers Coop'),
('PRT010', 'Tacloban Fish Port',        'Tacloban City',  'Leyte',           'Region VIII', 'Tacloban Coop');

-- dim_species (10 species)
INSERT INTO dw.dim_species (species_code, common_name, scientific_name, family, category) VALUES
('SPC001', 'Yellowfin Tuna',   'Thunnus albacares',       'Scombridae',    'Pelagic'),
('SPC002', 'Skipjack Tuna',    'Katsuwonus pelamis',      'Scombridae',    'Pelagic'),
('SPC003', 'Milkfish',         'Chanos chanos',           'Chanidae',      'Coastal'),
('SPC004', 'Tilapia',          'Oreochromis niloticus',   'Cichlidae',     'Freshwater'),
('SPC005', 'Blue Marlin',      'Makaira nigricans',       'Istiophoridae', 'Pelagic'),
('SPC006', 'Grouper',          'Epinephelus coioides',    'Serranidae',    'Demersal'),
('SPC007', 'Squid',            'Loligo duvaucelii',       'Loliginidae',   'Cephalopod'),
('SPC008', 'Shrimp',           'Penaeus monodon',         'Penaeidae',     'Crustacean'),
('SPC009', 'Sardine',          'Sardinella lemuru',       'Clupeidae',     'Pelagic'),
('SPC010', 'Mackerel',         'Rastrelliger kanagurta',  'Scombridae',    'Pelagic');

-- dim_vessel — initial current records (SCD2 version 1)
INSERT INTO dw.dim_vessel (vessel_code, vessel_name, vessel_type, gross_tonnage, owner_name, cooperative, effective_date, expiry_date, is_current) VALUES
('VSL001', 'Amanah I',      'Motorized Banca',  3.50,  'Ahmad Reyes',    'GenSan Fishers Coop',   '2020-01-01', '9999-12-31', TRUE),
('VSL002', 'Barakah II',    'Fishing Vessel',   25.00, 'Jose Santos',    'Navotas United Coop',   '2020-01-01', '9999-12-31', TRUE),
('VSL003', 'Rizal Star',    'Motorized Banca',  4.20,  'Maria Cruz',     'Iloilo Fishers Coop',   '2020-01-01', '9999-12-31', TRUE),
('VSL004', 'Davao Pride',   'Fishing Vessel',   30.00, 'Pedro Lim',      'Davao Fishers Coop',    '2020-01-01', '9999-12-31', TRUE),
('VSL005', 'Southern Cross','Trawler',          55.00, 'Ana Gomez',      'Zamboanga Coop',        '2020-01-01', '9999-12-31', TRUE),
('VSL006', 'Cebu Sunrise',  'Motorized Banca',  5.00,  'Luis Tan',       'Cebu Fishers Coop',     '2020-01-01', '9999-12-31', TRUE),
('VSL007', 'Quezon Fisher', 'Fishing Vessel',   18.00, 'Rosa Dela Cruz', 'Lucena Fishers Coop',   '2020-01-01', '9999-12-31', TRUE),
('VSL008', 'Batangas Bay',  'Motorized Banca',  3.80,  'Carlos Reyes',   'Batangas Coop',         '2020-01-01', '9999-12-31', TRUE),
('VSL009', 'Mindanao Star', 'Fishing Vessel',   22.00, 'Elena Bautista', 'CDO Fishers Coop',      '2020-01-01', '9999-12-31', TRUE),
('VSL010', 'Leyte Wave',    'Motorized Banca',  4.00,  'Ramon Villanueva','Tacloban Coop',        '2020-01-01', '9999-12-31', TRUE);


-- ============================================================
-- STEP 4b: Insert 200+ fact rows using generate_series
-- ============================================================
INSERT INTO dw.fact_landing (date_key, port_key, species_key, vessel_key, quantity_kg, price_per_kg, trip_days)
SELECT
    (SELECT date_key FROM dw.dim_date
     WHERE full_date = ('2020-01-01'::DATE + ((n % 1826) || ' days')::INTERVAL)::DATE) AS date_key,
    (n % 10) + 1                                    AS port_key,
    (n % 10) + 1                                    AS species_key,
    (n % 10) + 1                                    AS vessel_key,
    ROUND((50 + (n * 17 % 950))::NUMERIC, 2)        AS quantity_kg,
    ROUND((80 + (n * 13 % 420))::NUMERIC, 2)        AS price_per_kg,
    (1 + n % 7)                                     AS trip_days
FROM generate_series(1, 250) AS gs(n);


-- ============================================================
-- STEP 5: Star Queries
-- ============================================================

-- Query 1: Total kg landed per month (year-month)
SELECT
    d.year,
    d.month,
    TRIM(d.month_name)          AS month_name,
    SUM(f.quantity_kg)          AS total_kg,
    ROUND(SUM(f.total_value),2) AS total_value
FROM dw.fact_landing f
JOIN dw.dim_date    d ON f.date_key = d.date_key
GROUP BY d.year, d.month, d.month_name
ORDER BY d.year, d.month;


-- Query 2: Top species per port (by total kg)
SELECT
    p.port_name,
    p.province,
    s.common_name                           AS species,
    SUM(f.quantity_kg)                      AS total_kg,
    RANK() OVER (
        PARTITION BY p.port_key
        ORDER BY SUM(f.quantity_kg) DESC
    )                                       AS rank_in_port
FROM dw.fact_landing f
JOIN dw.dim_port    p ON f.port_key    = p.port_key
JOIN dw.dim_species s ON f.species_key = s.species_key
GROUP BY p.port_key, p.port_name, p.province, s.species_key, s.common_name
ORDER BY p.port_name, rank_in_port;


-- Query 3: Total value per cooperative
SELECT
    p.cooperative,
    COUNT(f.landing_key)            AS total_landings,
    SUM(f.quantity_kg)              AS total_kg,
    ROUND(SUM(f.total_value), 2)    AS total_value,
    ROUND(AVG(f.price_per_kg), 2)   AS avg_price_per_kg
FROM dw.fact_landing f
JOIN dw.dim_port p ON f.port_key = p.port_key
GROUP BY p.cooperative
ORDER BY total_value DESC;


-- ============================================================
-- STEP 6: SCD Type 2 — Change vessel VSL002 owner/cooperative
--
-- Scenario: "Barakah II" (VSL002) was sold to a new owner
--           effective 2024-06-01. Old fact rows must still
--           point to the old vessel_key and show old owner.
-- ============================================================

-- 6a. Expire the current record for VSL002
UPDATE dw.dim_vessel
SET
    expiry_date = '2024-05-31',
    is_current  = FALSE
WHERE vessel_code = 'VSL002'
  AND is_current  = TRUE;

-- 6b. Insert the new version of VSL002
INSERT INTO dw.dim_vessel (vessel_code, vessel_name, vessel_type, gross_tonnage, owner_name, cooperative, effective_date, expiry_date, is_current)
VALUES ('VSL002', 'Barakah II', 'Fishing Vessel', 25.00, 'NEW OWNER: Fatima Aquino', 'Cebu Fishers Coop', '2024-06-01', '9999-12-31', TRUE);

-- 6c. Verify: old fact rows still reference old vessel_key (unchanged)
--     New landings after 2024-06-01 would use the new vessel_key.

-- Show both versions of VSL002
SELECT
    vessel_key,
    vessel_code,
    vessel_name,
    owner_name,
    cooperative,
    effective_date,
    expiry_date,
    is_current
FROM dw.dim_vessel
WHERE vessel_code = 'VSL002'
ORDER BY effective_date;

-- Show that old fact rows still report old owner (history preserved)
SELECT
    f.landing_key,
    d.full_date,
    v.vessel_key,
    v.vessel_name,
    v.owner_name        AS owner_at_time_of_landing,
    v.cooperative,
    v.effective_date,
    v.expiry_date,
    f.quantity_kg,
    f.total_value
FROM dw.fact_landing f
JOIN dw.dim_date   d ON f.date_key   = d.date_key
JOIN dw.dim_vessel v ON f.vessel_key = v.vessel_key
WHERE v.vessel_code = 'VSL002'
ORDER BY d.full_date
LIMIT 20;
