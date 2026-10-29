# Fisheries Lab – ETL Pipeline & Star Schema

MSU-ICTO Fisheries Analytics | Labs 1–3

## Project Structure

```
fisheries_lab/
├── lab1_fisheries_star_schema.sql       # Lab 1: Star schema DDL + sample data
├── lab2_3_etl_pipeline.sql              # Labs 2-3: ETL pipeline (staging, cleaning, loading)
├── lab2_3_data_quality_report.md        # Data quality report
├── landings_2026.csv                    # Raw messy dataset (290 rows)
├── generate_messy_csv.py                # Script that generated the messy CSV
├── export_powerbi_csvs.py               # Script that exports clean CSVs for Power BI
├── fisheries_2026_summary_report.html   # Summary report (open in browser → Save as PDF)
├── powerbi/
│   ├── dim_date.csv                     # 173 date dimension rows
│   ├── dim_port.csv                     # 10 Philippine fish ports
│   ├── dim_species.csv                  # 10 species with scientific names
│   ├── dim_vessel.csv                   # 10 vessels (SCD Type 2)
│   └── fact_landing.csv                 # 257 clean landing transactions
└── Summary/
    ├── Star schema.pbix                 # Power BI report file
    └── Star schema.pdf                  # Exported PDF summary
```

## Star Schema

```
dim_date ──┐
dim_port ──┤──► fact_landing
dim_species┤
dim_vessel ┘
```

## ETL Pipeline Summary

| Stage | Description |
|-------|-------------|
| Raw | 290 rows loaded from `landings_2026.csv` |
| Rejected | 33 rows (missing values, duplicates, outliers) |
| Clean | 257 rows loaded into `fact_landing` |

## Data Quality Issues Found

- Missing values in critical columns (~15 rows)
- Duplicate rows (~10 rows)
- Outlier quantity > 10,000 kg (~5 rows)
- Outlier price > 2,000 PHP/kg (~8 rows)
- Inconsistent species names (~40 variants mapped to 10 canonical species)

## Power BI Report

- 4 KPI Cards: Total Landings (257), Total Value (42.13M), Quantity (141.70K), Avg Price
- Bar Chart: Species by quantity landed
- Line Chart: Monthly revenue trend
- Donut Chart: Category breakdown (Pelagic 51.97%)
- Table: Port performance (Zamboanga top at 5.83M)
