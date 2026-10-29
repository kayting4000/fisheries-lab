"""
Generates landings_2026.csv with intentional data quality issues:
- Missing values
- Duplicate rows
- Outliers (quantity, price)
- Inconsistent species names
"""
import csv, random, os

random.seed(42)

ports      = ['PRT001','PRT002','PRT003','PRT004','PRT005',
              'PRT006','PRT007','PRT008','PRT009','PRT010']
vessels    = ['VSL001','VSL002','VSL003','VSL004','VSL005',
              'VSL006','VSL007','VSL008','VSL009','VSL010']

# Intentionally messy species names mapping to real codes
species_variants = [
    ('SPC001', ['Yellowfin Tuna','yellowfin tuna','Yellow Fin Tuna','YF Tuna','Yellowfin']),
    ('SPC002', ['Skipjack Tuna','skipjack','Skip Jack Tuna','Skipjack tuna']),
    ('SPC003', ['Milkfish','milkfish','Milk Fish','MILKFISH','bangus']),
    ('SPC004', ['Tilapia','tilapia','TILAPIA','Tilapya']),
    ('SPC005', ['Blue Marlin','blue marlin','Bluemarlin','Blue-Marlin']),
    ('SPC006', ['Grouper','grouper','GROUPER','Lapu-lapu']),
    ('SPC007', ['Squid','squid','SQUID','pusit']),
    ('SPC008', ['Shrimp','shrimp','SHRIMP','Hipon']),
    ('SPC009', ['Sardine','sardine','Sardines','SARDINE']),
    ('SPC010', ['Mackerel','mackerel','MACKEREL','Hasa-hasa']),
]

header = ['landing_date','port_code','vessel_code','species_name',
          'quantity_kg','price_per_kg','trip_days']

rows = []
for n in range(1, 281):
    date = f"2026-{random.randint(1,12):02d}-{random.randint(1,28):02d}"
    port = random.choice(ports)
    vessel = random.choice(vessels)
    sp_code, variants = random.choice(species_variants)
    species = random.choice(variants)
    qty   = round(random.uniform(50, 1000), 2)
    price = round(random.uniform(80, 500), 2)
    days  = random.randint(1, 7)
    rows.append([date, port, vessel, species, qty, price, days])

# Inject issues
# 1. Missing values (15 rows)
for i in random.sample(range(len(rows)), 15):
    col = random.randint(0, 6)
    rows[i][col] = ''

# 2. Outliers — extreme quantity or price (5 rows)
for i in random.sample(range(len(rows)), 5):
    rows[i][4] = round(random.uniform(50000, 99999), 2)  # outlier qty

for i in random.sample(range(len(rows)), 5):
    rows[i][5] = round(random.uniform(5000, 9999), 2)    # outlier price

# 3. Duplicate rows (10 exact duplicates)
dupes = random.sample(rows[:100], 10)
rows.extend(dupes)

random.shuffle(rows)

out = os.path.join(os.path.dirname(__file__), 'landings_2026.csv')
with open(out, 'w', newline='') as f:
    w = csv.writer(f)
    w.writerow(header)
    w.writerows(rows)

print(f"Generated {len(rows)} rows -> {out}")
