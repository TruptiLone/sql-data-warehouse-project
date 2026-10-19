#!/usr/bin/env python3
"""Local CRM Silver DDL/load/validation; preserve and fingerprint all Bronze rows."""
import sys
sys.dont_write_bytecode = True
import hashlib
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('bronze_loader', HERE.parent / 'bronze/load_bronze.py')
local = importlib.util.module_from_spec(spec)
spec.loader.exec_module(local)

def fingerprint(schema, table):
    output = local.sql(f'SET NOCOUNT ON; SELECT * FROM [{schema}].[{table}] FOR JSON PATH, INCLUDE_NULL_VALUES;')
    rows = json.loads(''.join(output.splitlines()))
    canonical = sorted(json.dumps(row, sort_keys=True, ensure_ascii=False) for row in rows)
    return len(rows), hashlib.sha256('\n'.join(canonical).encode()).hexdigest()

def main():
    local.verify_container()
    before = {t: fingerprint('bronze', t) for t, _, _ in local.SPECS}
    try:
        print(local.sql((HERE / 'ddl_crm.sql').read_text()))
        print(local.sql((HERE / 'load_crm.sql').read_text()))
        print(local.sql((HERE / 'quality_checks.sql').read_text()))
        first = {t: fingerprint('silver', t) for t in ['crm_cust_info', 'crm_prd_info']}
        print('Rerun verification:')
        print(local.sql((HERE / 'load_crm.sql').read_text()))
        assert first == {t: fingerprint('silver', t) for t in first}, 'Rerun changed Silver rows or timestamps'
        print('PASS: rerun preserved every Silver value and warehouse timestamp.')
    finally:
        after = {t: fingerprint('bronze', t) for t in before}
        assert before == after, 'Bronze content changed during execution; investigate'
        print(f'PASS: all six Bronze fingerprints unchanged ({sum(v[0] for v in before.values()):,} rows).')

if __name__ == '__main__':
    main()
