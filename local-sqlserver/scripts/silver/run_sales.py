#!/usr/bin/env python3
"""Verify local scope, load sales safely, and independently reconcile every row."""
import sys
sys.dont_write_bytecode = True
import importlib.util
import json
from collections import Counter
from datetime import date
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('crm_runner', HERE / 'run_crm.py')
crm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(crm)
local = crm.local
FIELDS = ('sls_ord_num', 'sls_prd_key', 'sls_cust_id', 'sls_order_dt',
          'sls_ship_dt', 'sls_due_dt', 'sls_sales', 'sls_quantity', 'sls_price')

def fetch(schema, table):
    text = local.sql(f'SET NOCOUNT ON; SELECT * FROM [{schema}].[{table}] FOR JSON PATH, INCLUDE_NULL_VALUES;')
    return json.loads(''.join(text.splitlines()))

def convert_date(value):
    raw = str(value)
    if len(raw) != 8 or not raw.isascii() or not raw.isdigit():
        return None
    try:
        return date(int(raw[:4]), int(raw[4:6]), int(raw[6:])).isoformat()
    except ValueError:
        return None

def require(condition, message):
    if not condition:
        raise RuntimeError(message)

def oracle(source):
    """Independent Python arithmetic/date parsing, not a SQL-result replay."""
    expected = []
    counts = Counter()
    for row in source:
        item = dict(row)
        for key in FIELDS[:2]:
            item[key] = row[key].strip(' ')
            counts[key + '_trimmed'] += item[key] != row[key]
        for key in FIELDS[3:6]:
            item[key] = convert_date(row[key])
            counts[key + '_null'] += item[key] is None
        quantity, price, sales = row['sls_quantity'], row['sls_price'], row['sls_sales']
        require(quantity is not None and quantity > 0, 'Quantity requires review')
        if price is not None and price > 0:
            item['sls_sales'] = quantity * price
        else:
            require(sales is not None and sales > 0 and sales % quantity == 0,
                    'Cannot infer price without guessing')
            item['sls_price'] = sales // quantity
        counts['sales_amount_changed'] += item['sls_sales'] != sales
        counts['unit_price_changed'] += item['sls_price'] != price
        counts['quantity_changed'] += item['sls_quantity'] != quantity
        require(0 < item['sls_sales'] <= 2147483647, 'Sales exceeds INT range')
        expected.append(tuple(item[k] for k in FIELDS))
    return Counter(expected), counts

def main():
    local.verify_container()
    protected = [('bronze', t) for t, _, _ in local.SPECS] + [
        ('silver', 'crm_cust_info'), ('silver', 'crm_prd_info')]
    before = {key: crm.fingerprint(*key) for key in protected}
    source = fetch('bronze', 'crm_sales_details')
    expected, affected = oracle(source)
    try:
        print(local.sql((HERE / 'ddl_sales.sql').read_text()), flush=True)
        print(local.sql((HERE / 'load_sales.sql').read_text()), flush=True)
        print(local.sql((HERE / 'quality_sales.sql').read_text()), flush=True)
        actual = fetch('silver', 'crm_sales_details')
        require(Counter(tuple(row[k] for k in FIELDS) for row in actual) == expected,
                'Independent Python transformation differs from Silver')
        print('PASS: independent Python date/arithmetic oracle matches all rows and multiplicities.', flush=True)
        print(json.dumps(dict(source_rows=len(source), silver_rows=len(actual), affected=dict(affected)), sort_keys=True), flush=True)
        first = crm.fingerprint('silver', 'crm_sales_details')
        print('Rerun verification:', flush=True)
        print(local.sql((HERE / 'ddl_sales.sql').read_text()), flush=True)
        print(local.sql((HERE / 'load_sales.sql').read_text()), flush=True)
        require(first == crm.fingerprint('silver', 'crm_sales_details'), 'Rerun changed sales values or timestamps')
        print('PASS: rerun preserved every sales value and warehouse timestamp.', flush=True)
    finally:
        after = {key: crm.fingerprint(*key) for key in protected}
        require(before == after, 'Protected Bronze/customer/product content changed; investigate')
        print('PASS: all six Bronze tables and both existing CRM Silver tables unchanged.', flush=True)

if __name__ == '__main__':
    main()
