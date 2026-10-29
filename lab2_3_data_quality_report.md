# Labs 2–3: Data Quality Report
**Dataset:** `landings_2026.csv`  
**Pipeline:** `lab2_3_etl_pipeline.sql`  
**Target schema:** `dw` (star schema from Lab 1)

---

## 1. Issues Found

| # | Issue Type | Description | Rows Affected (approx.) |
|---|-----------|-------------|------------------------|
| 1 | **Missing values** | One or more critical columns (date, port, vessel, species, quantity, price, trip_days) were blank/NULL | ~15 |
| 2 | **Duplicate rows** | Exact duplicate records present in the raw file | ~10 |
| 3 | **Outlier – quantity** | `quantity_kg` > 10,000 kg (physically implausible for a single landing) | ~5 |
| 4 | **Outlier – price** | `price_per_kg` > 2,000 PHP (far above market range) | ~5 |
| 5 | **Inconsistent species names** | Same species entered with different casing, spacing, abbreviations, or local names (e.g. "bangus" vs "Milkfish", "pusit" vs "Squid") | ~40 distinct raw variants |

---

## 2. Rules Applied

| Rule | Action |
|------|--------|
| Any blank/NULL in a required column | Row **rejected** |
| Non-numeric value in `quantity_kg`, `price_per_kg`, or `trip_days` | Row **rejected** |
| Exact duplicate row | Keep one copy, extras **rejected** |
| `quantity_kg` ≤ 0 or > 10,000 | Row **rejected** as outlier |
| `price_per_kg` ≤ 0 or > 2,000 | Row **rejected** as outlier |
| `trip_days` < 1 or > 30 | Row **rejected** |
| Raw species name not found in `stg.species_map` | Row **rejected** (unmapped species) |
| Valid row with known species | Mapped to canonical `species_code` via `stg.species_map` |

---

## 3. Rows Rejected and Why

Rejected rows are stored in `stg.landings_rejected` with a `reject_reason` column.

| Reject Category | Estimated Count |
|----------------|----------------|
| Missing / blank field | ~15 |
| Exact duplicates removed | ~10 |
| Outlier quantity (> 10,000 kg) | ~5 |
| Outlier price (> 2,000 PHP/kg) | ~5 |
| Unmapped species name | 0 (all variants covered in species_map) |
| **Total rejected** | **~35** |
| **Total loaded to `dw.fact_landing`** | **~255** |

> Exact counts can be verified by running:
> ```sql
> SELECT COUNT(*) FROM stg.landings_clean;
> SELECT COUNT(*) FROM stg.landings_rejected;
> ```

---

## 4. Species Mapping Summary

The `stg.species_map` table normalises **10 species × ~3–4 variants each** to canonical `species_code` values from `dw.dim_species`.

| Canonical Name | Code | Sample Raw Variants Mapped |
|---------------|------|---------------------------|
| Yellowfin Tuna | SPC001 | "yellowfin tuna", "YF Tuna", "Yellowfin" |
| Skipjack Tuna | SPC002 | "skipjack", "Skip Jack Tuna" |
| Milkfish | SPC003 | "Milk Fish", "MILKFISH", "bangus" |
| Tilapia | SPC004 | "TILAPIA", "Tilapya" |
| Blue Marlin | SPC005 | "Bluemarlin", "Blue-Marlin" |
| Grouper | SPC006 | "GROUPER", "Lapu-lapu" |
| Squid | SPC007 | "SQUID", "pusit" |
| Shrimp | SPC008 | "SHRIMP", "Hipon" |
| Sardine | SPC009 | "Sardines", "SARDINE" |
| Mackerel | SPC010 | "MACKEREL", "Hasa-hasa" |

---

## 5. ETL Flow Summary

```
landings_2026.csv
      |
      v  \copy
stg.landings_raw          (all 290 raw rows, TEXT columns)
      |
      v  Dedup + type cast + NULL filter + outlier filter
      |  + species_map JOIN
      v
stg.landings_clean        (~255 rows, typed columns)
      |
      +---> dw.dim_port    (upsert new ports)
      +---> dw.dim_vessel  (upsert new vessels, SCD2-aware)
      +---> dw.fact_landing (INSERT ... SELECT via dim JOINs)
      |
      v
stg.landings_rejected     (~35 rows with reject_reason)
```
