"""
Cleans landings_2026.csv and exports star schema CSVs for Power BI:
  powerbi/dim_date.csv
  powerbi/dim_port.csv
  powerbi/dim_species.csv
  powerbi/dim_vessel.csv
  powerbi/fact_landing.csv
"""
import csv, os, math
from datetime import date, timedelta

BASE = os.path.dirname(os.path.abspath(__file__))
OUT  = os.path.join(BASE, 'powerbi')
os.makedirs(OUT, exist_ok=True)

# ── Species mapping (raw lowercase → canonical) ──────────────────────────────
SPECIES_MAP = {
    'yellowfin tuna':'SPC001','yellow fin tuna':'SPC001',
    'yf tuna':'SPC001','yellowfin':'SPC001',
    'skipjack tuna':'SPC002','skipjack':'SPC002','skip jack tuna':'SPC002',
    'milkfish':'SPC003','milk fish':'SPC003','bangus':'SPC003',
    'tilapia':'SPC004','tilapya':'SPC004',
    'blue marlin':'SPC005','bluemarlin':'SPC005','blue-marlin':'SPC005',
    'grouper':'SPC006','lapu-lapu':'SPC006',
    'squid':'SPC007','pusit':'SPC007',
    'shrimp':'SPC008','hipon':'SPC008',
    'sardine':'SPC009','sardines':'SPC009',
    'mackerel':'SPC010','hasa-hasa':'SPC010',
}

SPECIES_MASTER = {
    'SPC001':('Yellowfin Tuna',  'Thunnus albacares',      'Scombridae',    'Pelagic'),
    'SPC002':('Skipjack Tuna',   'Katsuwonus pelamis',     'Scombridae',    'Pelagic'),
    'SPC003':('Milkfish',        'Chanos chanos',          'Chanidae',      'Coastal'),
    'SPC004':('Tilapia',         'Oreochromis niloticus',  'Cichlidae',     'Freshwater'),
    'SPC005':('Blue Marlin',     'Makaira nigricans',      'Istiophoridae', 'Pelagic'),
    'SPC006':('Grouper',         'Epinephelus coioides',   'Serranidae',    'Demersal'),
    'SPC007':('Squid',           'Loligo duvaucelii',      'Loliginidae',   'Cephalopod'),
    'SPC008':('Shrimp',          'Penaeus monodon',        'Penaeidae',     'Crustacean'),
    'SPC009':('Sardine',         'Sardinella lemuru',      'Clupeidae',     'Pelagic'),
    'SPC010':('Mackerel',        'Rastrelliger kanagurta', 'Scombridae',    'Pelagic'),
}

PORT_MASTER = {
    'PRT001':('General Santos Fish Port','General Santos','South Cotabato','Region XII','GenSan Fishers Coop'),
    'PRT002':('Navotas Fish Port','Navotas','Metro Manila','NCR','Navotas United Coop'),
    'PRT003':('Iloilo Fish Port','Iloilo City','Iloilo','Region VI','Iloilo Fishers Coop'),
    'PRT004':('Davao Fish Port','Davao City','Davao del Sur','Region XI','Davao Fishers Coop'),
    'PRT005':('Zamboanga Fish Port','Zamboanga City','Zamboanga del Sur','Region IX','Zamboanga Coop'),
    'PRT006':('Cebu Fish Port','Cebu City','Cebu','Region VII','Cebu Fishers Coop'),
    'PRT007':('Lucena Fish Port','Lucena City','Quezon','Region IV-A','Lucena Fishers Coop'),
    'PRT008':('Batangas Fish Port','Batangas City','Batangas','Region IV-A','Batangas Coop'),
    'PRT009':('Cagayan de Oro Fish Port','Cagayan de Oro','Misamis Oriental','Region X','CDO Fishers Coop'),
    'PRT010':('Tacloban Fish Port','Tacloban City','Leyte','Region VIII','Tacloban Coop'),
}

VESSEL_MASTER = {
    'VSL001':('Amanah I','Motorized Banca',3.50,'Ahmad Reyes','GenSan Fishers Coop'),
    'VSL002':('Barakah II','Fishing Vessel',25.00,'Jose Santos','Navotas United Coop'),
    'VSL003':('Rizal Star','Motorized Banca',4.20,'Maria Cruz','Iloilo Fishers Coop'),
    'VSL004':('Davao Pride','Fishing Vessel',30.00,'Pedro Lim','Davao Fishers Coop'),
    'VSL005':('Southern Cross','Trawler',55.00,'Ana Gomez','Zamboanga Coop'),
    'VSL006':('Cebu Sunrise','Motorized Banca',5.00,'Luis Tan','Cebu Fishers Coop'),
    'VSL007':('Quezon Fisher','Fishing Vessel',18.00,'Rosa Dela Cruz','Lucena Fishers Coop'),
    'VSL008':('Batangas Bay','Motorized Banca',3.80,'Carlos Reyes','Batangas Coop'),
    'VSL009':('Mindanao Star','Fishing Vessel',22.00,'Elena Bautista','CDO Fishers Coop'),
    'VSL010':('Leyte Wave','Motorized Banca',4.00,'Ramon Villanueva','Tacloban Coop'),
}

MONTH_NAMES = ['','January','February','March','April','May','June',
               'July','August','September','October','November','December']
DAY_NAMES   = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday']

# ── 1. Read & clean raw CSV ───────────────────────────────────────────────────
raw_path = os.path.join(BASE, 'landings_2026.csv')
clean_rows, rejected, seen = [], [], set()

with open(raw_path, newline='', encoding='utf-8') as f:
    for row in csv.DictReader(f):
        ld  = row['landing_date'].strip()
        pc  = row['port_code'].strip()
        vc  = row['vessel_code'].strip()
        sn  = row['species_name'].strip()
        qty = row['quantity_kg'].strip()
        prc = row['price_per_kg'].strip()
        td  = row['trip_days'].strip()

        # reject missing
        if not all([ld, pc, vc, sn, qty, prc, td]):
            rejected.append(row); continue

        # reject non-numeric
        try:
            qty_f = float(qty); prc_f = float(prc); td_i = int(td)
        except ValueError:
            rejected.append(row); continue

        # reject outliers
        if not (1 <= qty_f <= 10000 and 1 <= prc_f <= 2000 and 1 <= td_i <= 30):
            rejected.append(row); continue

        # map species
        sc = SPECIES_MAP.get(sn.lower())
        if sc is None:
            rejected.append(row); continue

        # dedup
        key = (ld, pc, vc, sc, qty, prc, td)
        if key in seen:
            rejected.append(row); continue
        seen.add(key)

        clean_rows.append({'landing_date':ld,'port_code':pc,'vessel_code':vc,
                           'species_code':sc,'quantity_kg':qty_f,
                           'price_per_kg':prc_f,'trip_days':td_i})

print(f"Clean: {len(clean_rows)}  Rejected: {len(rejected)}")

# ── 2. Collect used keys ──────────────────────────────────────────────────────
used_dates    = sorted({r['landing_date'] for r in clean_rows})
used_ports    = sorted({r['port_code']    for r in clean_rows})
used_vessels  = sorted({r['vessel_code']  for r in clean_rows})
used_species  = sorted({r['species_code'] for r in clean_rows})

# ── 3. dim_date ───────────────────────────────────────────────────────────────
date_rows = []
for ds in used_dates:
    d = date.fromisoformat(ds)
    iso = d.isocalendar()
    date_rows.append({
        'date_key':    int(d.strftime('%Y%m%d')),
        'full_date':   ds,
        'day':         d.day,
        'month':       d.month,
        'month_name':  MONTH_NAMES[d.month],
        'quarter':     (d.month - 1) // 3 + 1,
        'year':        d.year,
        'week_of_year':iso[1],
        'day_of_week': iso[2],
        'day_name':    DAY_NAMES[iso[2]-1],
        'is_weekend':  iso[2] in (6,7),
    })

date_key_map = {r['full_date']: r['date_key'] for r in date_rows}

with open(os.path.join(OUT,'dim_date.csv'),'w',newline='',encoding='utf-8') as f:
    w = csv.DictWriter(f, fieldnames=list(date_rows[0].keys()))
    w.writeheader(); w.writerows(date_rows)

# ── 4. dim_port ───────────────────────────────────────────────────────────────
port_rows = []
for i, pc in enumerate(used_ports, 1):
    m = PORT_MASTER.get(pc, (pc,'Unknown','Unknown','Unknown','Unknown'))
    port_rows.append({'port_key':i,'port_code':pc,'port_name':m[0],
                      'municipality':m[1],'province':m[2],'region':m[3],'cooperative':m[4]})
port_key_map = {r['port_code']: r['port_key'] for r in port_rows}

with open(os.path.join(OUT,'dim_port.csv'),'w',newline='',encoding='utf-8') as f:
    w = csv.DictWriter(f, fieldnames=list(port_rows[0].keys()))
    w.writeheader(); w.writerows(port_rows)

# ── 5. dim_species ────────────────────────────────────────────────────────────
species_rows = []
for i, sc in enumerate(used_species, 1):
    m = SPECIES_MASTER[sc]
    species_rows.append({'species_key':i,'species_code':sc,'common_name':m[0],
                         'scientific_name':m[1],'family':m[2],'category':m[3]})
species_key_map = {r['species_code']: r['species_key'] for r in species_rows}

with open(os.path.join(OUT,'dim_species.csv'),'w',newline='',encoding='utf-8') as f:
    w = csv.DictWriter(f, fieldnames=list(species_rows[0].keys()))
    w.writeheader(); w.writerows(species_rows)

# ── 6. dim_vessel ─────────────────────────────────────────────────────────────
vessel_rows = []
for i, vc in enumerate(used_vessels, 1):
    m = VESSEL_MASTER.get(vc, (vc,'Unknown',0,'Unknown','Unknown'))
    vessel_rows.append({'vessel_key':i,'vessel_code':vc,'vessel_name':m[0],
                        'vessel_type':m[1],'gross_tonnage':m[2],
                        'owner_name':m[3],'cooperative':m[4],
                        'effective_date':'2026-01-01','expiry_date':'9999-12-31','is_current':True})
vessel_key_map = {r['vessel_code']: r['vessel_key'] for r in vessel_rows}

with open(os.path.join(OUT,'dim_vessel.csv'),'w',newline='',encoding='utf-8') as f:
    w = csv.DictWriter(f, fieldnames=list(vessel_rows[0].keys()))
    w.writeheader(); w.writerows(vessel_rows)

# ── 7. fact_landing ───────────────────────────────────────────────────────────
fact_rows = []
for i, r in enumerate(clean_rows, 1):
    qty = round(r['quantity_kg'], 2)
    prc = round(r['price_per_kg'], 2)
    fact_rows.append({
        'landing_key':  i,
        'date_key':     date_key_map[r['landing_date']],
        'port_key':     port_key_map[r['port_code']],
        'species_key':  species_key_map[r['species_code']],
        'vessel_key':   vessel_key_map[r['vessel_code']],
        'quantity_kg':  qty,
        'price_per_kg': prc,
        'total_value':  round(qty * prc, 2),
        'trip_days':    r['trip_days'],
    })

with open(os.path.join(OUT,'fact_landing.csv'),'w',newline='',encoding='utf-8') as f:
    w = csv.DictWriter(f, fieldnames=list(fact_rows[0].keys()))
    w.writeheader(); w.writerows(fact_rows)

print("Exported to powerbi/:")
for fn in ['dim_date.csv','dim_port.csv','dim_species.csv','dim_vessel.csv','fact_landing.csv']:
    path = os.path.join(OUT, fn)
    with open(path) as ff:
        lines = sum(1 for _ in ff) - 1
    print(f"  {fn}: {lines} rows")
