#!/usr/bin/env python3
"""Inspect, prepare lossless CSV copies, load local Bronze, and compare every row."""
import csv
import io
import json
import re
import subprocess
from collections import Counter
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
DATA = ROOT / 'local-sqlserver/datasets'
CONTAINER = 'retailflow-sql-local'
SPECS = [
    ('crm_cust_info', 'source_crm/cust_info.csv', 'cst_id'),
    ('crm_prd_info', 'source_crm/prd_info.csv', 'prd_id'),
    ('crm_sales_details', 'source_crm/sales_details.csv', 'sls_ord_num'),
    ('erp_cust_az12', 'source_erp/CUST_AZ12.csv', 'cid'),
    ('erp_loc_a101', 'source_erp/LOC_A101.csv', 'cid'),
    ('erp_px_cat_g1v2', 'source_erp/PX_CAT_G1V2.csv', 'id'),
]

def sql(query):
    result = subprocess.run(
        ['docker', 'exec', '-i', CONTAINER, 'sh', '-c',
         'SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" /opt/mssql-tools18/bin/sqlcmd '
         '-S tcp:127.0.0.1,1433 -U sa -C -b -l 15 -d DataWarehouse -y 0 -w 65535'],
        input=query, text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout.strip()

def verify_container():
    # Filter inspect output: never retrieve container environment credentials.
    value = subprocess.check_output(['docker', 'inspect', '--format',
        '{"ports":{{json .NetworkSettings.Ports}},"mounts":{{json .Mounts}},'
        '"host":{{json .Config.Hostname}},"image":{{json .Image}}}', CONTAINER], text=True)
    info = json.loads(value)
    assert info['ports'].get('1433/tcp') == [{'HostIp': '127.0.0.1', 'HostPort': '14333'}]
    assert any(m['Destination'] == '/var/opt/mssql' and
               m.get('Name') == 'local-sqlserver_retailflow_sql_fresh' for m in info['mounts'])
    assert any(m['Destination'] == '/var/opt/retailflow-datasets' and
               m['Source'] == str(DATA) and not m['RW'] for m in info['mounts'])
    assert info['image'] == 'sha256:7fb2139341715e8a71843cfc2f02bab6e95f1c52c0fa9f9a6b2e7b761f060780'
    assert sql("SET NOCOUNT ON; SELECT CONVERT(nvarchar(128),SERVERPROPERTY('MachineName'));") == info['host']
    print('Verified local Docker identity, unchanged image/volume, and read-only source mount.')

def normalize(value, typ):
    if value is None or value == '':
        return None
    if typ == 'INT':
        return int(value)
    if typ == 'DATE':
        return datetime.fromisoformat(value).date().isoformat()
    if typ == 'DATETIME':
        return datetime.fromisoformat(value).isoformat(timespec='milliseconds')
    return value  # Preserve Unicode, whitespace, and raw categories.

def main():
    verify_container()
    original = (ROOT / 'scripts/bronze/ddl_bronze.sql').read_text()
    prepared = DATA / '.bulk'
    prepared.mkdir(exist_ok=True)
    manifest = []
    sources = {}
    for table, relative, identifier in SPECS:
        raw = (DATA / relative).read_bytes()
        rows = list(csv.reader(io.StringIO(raw.decode('utf-8-sig'), newline=''), strict=True))
        header, records = rows[0], rows[1:]
        body = re.search(r'CREATE TABLE bronze\.' + table + r'\s*\((.*?)\);', original, re.S).group(1)
        columns = re.findall(r'(\w+)\s+(NVARCHAR\(50\)|INT|DATETIME|DATE)', body, re.I)
        assert [x.lower() for x in header] == [x[0] for x in columns]
        assert all(len(row) == len(columns) for row in records)
        target = prepared / (table + '.csv')
        with target.open('w', encoding='utf-16', newline='') as f:
            writer = csv.writer(f, lineterminator='\n')
            writer.writerow(header)
            writer.writerows(records)
        with target.open(encoding='utf-16', newline='') as f:
            assert list(csv.reader(f, strict=True)) == rows
        sources[table] = (columns, records, identifier)
        manifest.append(dict(table=table, source=relative, source_rows=len(records),
            encoding='UTF-8', delimiter=',', quote='"', quote_characters=raw.count(b'"'),
            crlf=raw.count(b'\r\n'), final_newline=raw.endswith(b'\n')))
    (prepared / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    # Count variables are computed with the CSV parser, never by counting newlines.
    settings = '\n'.join(f":setvar {m['table']}_rows {m['source_rows']}" for m in manifest)
    print(sql(settings + '\n' + Path(__file__).with_name('load_bronze.sql').read_text()))
    for table, (columns, records, identifier) in sources.items():
        # JSON preserves embedded newlines as escapes; sqlcmd display wraps are removed.
        output = sql(f'SET NOCOUNT ON; SELECT * FROM bronze.[{table}] FOR JSON PATH, INCLUDE_NULL_VALUES;')
        actual = json.loads(''.join(output.splitlines()))
        expected = Counter(tuple(normalize(v, typ) for v, (_, typ) in zip(row, columns)) for row in records)
        observed = Counter(tuple(normalize(row[name], typ) for name, typ in columns) for row in actual)
        assert observed == expected, f'{table}: full row multiset mismatch; inspect, never reload blindly'
        first = tuple(normalize(v, typ) for v, (_, typ) in zip(records[0], columns))
        last = tuple(normalize(v, typ) for v, (_, typ) in zip(records[-1], columns))
        assert observed[first] == expected[first] and observed[last] == expected[last]
        ids = Counter(row[identifier] for row in actual)
        print(json.dumps(dict(table=table, source_rows=len(records), table_rows=len(actual),
            status='PASS: full row multiset and first/last source records match',
            null_identifiers=ids.get(None, 0),
            duplicate_nonnull_identifier_groups=sum(v > 1 for k,v in ids.items() if k is not None),
            duplicate_identifier_excess_rows=sum(v-1 for k,v in ids.items() if k is not None and v>1),
            duplicate_full_row_excess=sum(v-1 for v in observed.values() if v>1))))

if __name__ == '__main__':
    main()
