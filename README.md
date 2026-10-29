# 🐟 Fisheries Landing Analytics 2026

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-blue?logo=postgresql&logoColor=white)
![Power BI](https://img.shields.io/badge/Power%20BI-Report-yellow?logo=powerbi&logoColor=black)
![Python](https://img.shields.io/badge/Python-3.x-green?logo=python&logoColor=white)
![ETL](https://img.shields.io/badge/ETL-Pipeline-orange)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

> **MSU-ICTO Fisheries Analytics** | Labs 1–3  
> Star Schema Design · ETL Pipeline · Data Cleaning · Power BI Dashboard

---

## 📊 Dashboard Preview

| KPI | Value |
|-----|-------|
| 🎣 Total Landings | **257** |
| 💰 Total Revenue | **₱42.13M** |
| ⚖️ Total Quantity | **141.70K kg** |
| 📍 Top Port | **Zamboanga (₱5.83M)** |
| 🐠 Top Species | **Grouper** |
| 🏆 Dominant Category | **Pelagic (51.97%)** |

---

## 🗂️ Project Structure

```
fisheries_lab/
├── 📄 lab1_fisheries_star_schema.sql       ← Star schema DDL + sample data
├── 📄 lab2_3_etl_pipeline.sql              ← ETL pipeline (staging → clean → load)
├── 📄 lab2_3_data_quality_report.md        ← Data quality report
├── 📄 landings_2026.csv                    ← Raw messy dataset (290 rows)
├── 🐍 generate_messy_csv.py                ← Generates the messy CSV
├── 🐍 export_powerbi_csvs.py               ← Exports clean CSVs for Power BI
├── 🌐 fisheries_2026_summary_report.html   ← Summary report (open → Save as PDF)
├── 📁 powerbi/
│   ├── dim_date.csv                        ← 173 date dimension rows
│   ├── dim_port.csv                        ← 10 Philippine fish ports
│   ├── dim_species.csv                     ← 10 species with scientific names
│   ├── dim_vessel.csv                      ← 10 vessels (SCD Type 2)
│   └── fact_landing.csv                    ← 257 clean landing transactions
└── 📁 Summary/
    ├── Star schema.pbix                    ← Power BI report file
    └── Star schema.pdf                     ← Exported PDF summary
```

---

## ⭐ Star Schema

```
                    ┌─────────────┐
                    │  dim_date   │
                    │─────────────│
                    │ PK date_key │
                    │ full_date   │
                    │ month_name  │
                    │ quarter     │
                    └──────┬──────┘
                           │
┌─────────────┐    ┌───────▼────────┐    ┌──────────────┐
│  dim_port   │    │  fact_landing  │    │ dim_species  │
│─────────────│    │────────────────│    │──────────────│
│ PK port_key ├───►│ FK date_key    │◄───┤PK species_key│
│ port_name   │    │ FK port_key    │    │ common_name  │
│ province    │    │ FK species_key │    │ scientific_  │
│ region      │    │ FK vessel_key  │    │   name       │
│ cooperative │    │ quantity_kg    │    │ category     │
└─────────────┘    │ price_per_kg   │    └──────────────┘
                   │ total_value    │
                   │ trip_days      │    ┌──────────────┐
                   └───────┬────────┘    │  dim_vessel  │
                           │             │──────────────│
                           └────────────►│PK vessel_key │
                                         │ vessel_name  │
                                         │ vessel_type  │
                                         │ owner_name   │
                                         │ is_current   │
                                         └──────────────┘
```

---

## 🔄 ETL Pipeline

```
landings_2026.csv (290 rows)
        │
        ▼  \copy
stg.landings_raw          ← all raw TEXT rows
        │
        ▼  Clean & Transform
   ┌────┴────────────────────────────────────┐
   │  • Remove duplicates (~10)              │
   │  • Drop missing fields (~15)            │
   │  • Filter outliers qty>10K, price>2K    │
   │  • Map species names via species_map    │
   └────┬────────────────────────────────────┘
        │
        ▼
stg.landings_clean (257 rows)
        │
        ├──► dw.dim_port     (upsert)
        ├──► dw.dim_vessel   (upsert, SCD Type 2)
        └──► dw.fact_landing (INSERT ... SELECT)

stg.landings_rejected (33 rows) ← logged with reason
```

---

## 🧹 Data Quality Summary

| Issue | Count | Action |
|-------|-------|--------|
| Missing values | ~15 rows | Rejected |
| Duplicate rows | ~10 rows | Deduplicated |
| Outlier quantity (>10,000 kg) | ~5 rows | Rejected |
| Outlier price (>2,000 PHP/kg) | ~8 rows | Rejected |
| Inconsistent species names | ~40 variants | Mapped to 10 canonical |
| **Total Rejected** | **33** | |
| **Total Loaded** | **257** | ✅ |

---

## 🐠 Species Mapping

| Canonical Name | Code | Local/Variant Names |
|---------------|------|---------------------|
| Yellowfin Tuna | SPC001 | YF Tuna, Yellow Fin Tuna, Yellowfin |
| Skipjack Tuna | SPC002 | skipjack, Skip Jack Tuna |
| Milkfish | SPC003 | Milk Fish, MILKFISH, **bangus** |
| Tilapia | SPC004 | TILAPIA, **Tilapya** |
| Blue Marlin | SPC005 | Bluemarlin, Blue-Marlin |
| Grouper | SPC006 | GROUPER, **Lapu-lapu** |
| Squid | SPC007 | SQUID, **pusit** |
| Shrimp | SPC008 | SHRIMP, **Hipon** |
| Sardine | SPC009 | Sardines, SARDINE |
| Mackerel | SPC010 | MACKEREL, **Hasa-hasa** |

---

## 🏗️ How to Run

### 1. Generate messy CSV
```bash
python generate_messy_csv.py
```

### 2. Run Lab 1 – Star Schema (PostgreSQL)
```sql
\i lab1_fisheries_star_schema.sql
```

### 3. Run Labs 2–3 – ETL Pipeline
```sql
\i lab2_3_etl_pipeline.sql
-- Then load the CSV:
\copy stg.landings_raw FROM 'landings_2026.csv' CSV HEADER;
```

### 4. Export Power BI CSVs
```bash
python export_powerbi_csvs.py
```

### 5. Open Power BI
- Load all 5 CSVs from `powerbi/` using **Get Data → Text/CSV**
- Connect relationships in **Model View**
- Open `Summary/Star schema.pbix` for the full report

---

## 🛠️ Tech Stack

| Tool | Purpose |
|------|---------|
| PostgreSQL 16 | Star schema + ETL pipeline |
| Python 3 | CSV generation + data export |
| Power BI Desktop | Dashboard + PDF report |
| Git + GitHub | Version control |

---

## 📁 Key Files

| File | Description |
|------|-------------|
| [`lab1_fisheries_star_schema.sql`](lab1_fisheries_star_schema.sql) | DDL for all tables + sample data |
| [`lab2_3_etl_pipeline.sql`](lab2_3_etl_pipeline.sql) | Full ETL pipeline |
| [`lab2_3_data_quality_report.md`](lab2_3_data_quality_report.md) | Data quality findings |
| [`Summary/Star schema.pdf`](Summary/Star%20schema.pdf) | Power BI PDF report |

---

*MSU-ICTO · Fisheries Analytics Lab · 2026*
