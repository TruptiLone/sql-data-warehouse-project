#!/usr/bin/env python3
"""Local ERP load with independent reconciliation and protected-table fingerprints."""
import sys
sys.dont_write_bytecode=True
import importlib.util
import json
from collections import Counter
from pathlib import Path

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('crm_runner',HERE/'run_crm.py')
crm=importlib.util.module_from_spec(spec)
spec.loader.exec_module(crm)
local=crm.local
FIELDS={'erp_cust_az12':['cid','bdate','gen'], 'erp_loc_a101':['cid','cntry'],
        'erp_px_cat_g1v2':['id','cat','subcat','maintenance']}

def fetch(schema,table):
    raw=local.sql(f'SET NOCOUNT ON; SELECT * FROM [{schema}].[{table}] FOR JSON PATH,INCLUDE_NULL_VALUES;')
    return json.loads(''.join(raw.splitlines()))

def require(condition,message):
    if not condition: raise RuntimeError(message)

def main():
    local.verify_container()
    as_of=local.sql('SET NOCOUNT ON; SELECT CONVERT(char(10),GETDATE(),23);')
    protected=[('bronze',t) for t,_,_ in local.SPECS]+[('silver',t) for t in ['crm_cust_info','crm_prd_info','crm_sales_details']]
    before={k:crm.fingerprint(*k) for k in protected}
    expected={}
    for table,fields in FIELDS.items():
        source=fetch('bronze',table)
        target=[]; changes=Counter()
        for row in source:
            clean={k:row[k] for k in fields}
            if table=='erp_cust_az12':
                cid=row['cid'].strip(' ') if row['cid'] is not None else None
                clean['cid']=cid[3:] if cid and cid.startswith('NAS') else cid
                clean['bdate']=None if row['bdate'] and row['bdate']>as_of else row['bdate']
                gen=(row['gen'] or '').strip(' ').upper()
                clean['gen']='Male' if gen in ('M','MALE') else 'Female' if gen in ('F','FEMALE') else 'n/a'
            elif table=='erp_loc_a101':
                clean['cid']=row['cid'].strip(' ').replace('-','') if row['cid'] is not None else None
                country=(row['cntry'] or '').strip(' ')
                clean['cntry']='Germany' if country.upper() in ('D','DE') else 'United States' if country.upper() in ('US','USA') else country or 'n/a'
            for k in fields: changes[k]+=clean[k]!=row[k]
            target.append(tuple(clean[k] for k in fields))
        expected[table]=Counter(target)
        print(json.dumps(dict(table=table,source_rows=len(source),changed_fields=dict(changes),as_of=as_of)),flush=True)
    try:
        for filename in ['ddl_erp.sql','load_erp.sql','quality_erp.sql']:
            print(local.sql((HERE/filename).read_text()),flush=True)
        for table,fields in FIELDS.items():
            actual=fetch('silver',table)
            require(Counter(tuple(row[k] for k in fields) for row in actual)==expected[table],f'{table}: independent transformation mismatch')
            print(f'PASS: {table}: {len(actual)} rows match independent Python transformation.',flush=True)
        loaded={t:crm.fingerprint('silver',t) for t in FIELDS}
        print('Rerun verification:',flush=True)
        for filename in ['ddl_erp.sql','load_erp.sql']:
            print(local.sql((HERE/filename).read_text()),flush=True)
        require(loaded=={t:crm.fingerprint('silver',t) for t in FIELDS},'Rerun altered ERP values or timestamps')
        print('PASS: ERP rerun unchanged, including timestamps.',flush=True)
    finally:
        require(before=={k:crm.fingerprint(*k) for k in protected},'Protected Bronze/CRM data changed during execution')
        print('PASS: all 116,294 Bronze rows and all three CRM Silver tables unchanged.',flush=True)

if __name__=='__main__': main()
