#!/usr/bin/env python3
"""Preview by default. Refresh/test require explicit authorization flag after review."""
import argparse
import hashlib
import importlib.util
import json
import re
import subprocess
import sys
from pathlib import Path
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('crm',HERE.parent/'run_crm.py')
crm=importlib.util.module_from_spec(spec);spec.loader.exec_module(crm)
local=crm.local
NAMES=[t for t,_,_ in local.SPECS]


def require(value,message):
    if not value: raise RuntimeError(message)


def query(sql):
    return subprocess.run(['docker','exec','-i',local.CONTAINER,'sh','-c',
        'SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" /opt/mssql-tools18/bin/sqlcmd '
        '-S tcp:127.0.0.1,1433 -U sa -C -b -l 15 -d DataWarehouse -y 0 -w 65535'],
        input=sql,text=True,capture_output=True)


def snapshot(schema, business_only=False):
    result={}
    for table in NAMES:
        output=local.sql(f'SET NOCOUNT ON; SELECT * FROM [{schema}].[{table}] FOR JSON PATH,INCLUDE_NULL_VALUES;')
        rows=json.loads(''.join(output.splitlines()))
        if business_only:
            for row in rows: row.pop('dwh_create_date',None)
        data=sorted(json.dumps(r,sort_keys=True,ensure_ascii=False) for r in rows)
        result[table]=(len(rows),hashlib.sha256('\n'.join(data).encode()).hexdigest())
    return result


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('mode',choices=['preview','refresh','test'],nargs='?',default='preview')
    parser.add_argument('--confirm-local-silver-refresh',action='store_true',help='Use only after explicit user approval of populated-table TRUNCATE.')
    args=parser.parse_args()
    require(args.mode=='preview' or args.confirm_local_silver_refresh,
            'Approval required: preview first; refresh/test require --confirm-local-silver-refresh.')
    subprocess.run([sys.executable,str(HERE/'build.py'),'--check'],check=True)
    local.verify_container()
    host=local.sql("SET NOCOUNT ON; SELECT CONVERT(sysname,SERVERPROPERTY('MachineName'));")
    require(re.fullmatch(r'[a-zA-Z0-9_-]+',host),'Unexpected Docker machine identifier')
    # Existing production tables are never created/redefined by this runner.
    before_bronze=snapshot('bronze')
    before_silver=snapshot('silver')
    business=snapshot('silver',True)
    path=HERE/'refresh_all.sql'
    existing=local.sql("SET NOCOUNT ON; SELECT OBJECT_DEFINITION(OBJECT_ID('silver.refresh_all'));")
    if existing not in ('','NULL'):
        require('RetailFlow360.Silver.FullRefresh' in existing,'Unrecognized existing silver.refresh_all procedure; stop for review.')
    print(local.sql(path.read_text()),flush=True)  # Deploy definition only; never executes TRUNCATE.

    def invoke(apply=False,failure=None):
        call=f"EXEC silver.refresh_all @expected_machine=N'{host}', @execute_refresh={int(apply)}"
        if apply: call+=", @confirmation=N'REFRESH SIX LOCAL SILVER TABLES'"
        if failure: call+=f", @inject_failure='{failure}'"
        return query(call+';')

    def success(apply=False):
        result=invoke(apply)
        require(result.returncode==0,result.stdout+result.stderr)
        print(result.stdout,flush=True)

    try:
        if args.mode=='preview':
            success(False)
            require(before_silver==snapshot('silver'),'Preview changed Silver')
            print('PASS: preview left every Silver row and timestamp unchanged.',flush=True)
        elif args.mode=='refresh':
            success(True)
        else:
            # Approval covers two successful refreshes and two deliberate rollbacks.
            success(True)
            first=snapshot('silver')
            require(business==snapshot('silver',True),'First refresh changed business values on current snapshot')
            success(True)
            second=snapshot('silver')
            require(business==snapshot('silver',True),'Second refresh changed business values')
            require(all(first[t]!=second[t] for t in NAMES),'A table did not receive a fresh timestamp')
            print('PASS: two refreshes preserve business values/counts with renewed timestamps.',flush=True)
            for failure,error in [('after_truncate',51390),('validation',51391)]:
                result=invoke(True,failure)
                require(result.returncode!=0 and f'Msg {error},' in result.stdout+result.stderr,
                        'Failure injection did not return expected SQL error: '+result.stdout+result.stderr)
                require(second==snapshot('silver'),f'{failure}: rollback did not restore complete Silver values/timestamps')
                print(f'PASS: {failure} error {error}; all six Silver tables restored exactly.',flush=True)
    finally:
        require(before_bronze==snapshot('bronze'),'Bronze changed during refresh/preview')
        print('PASS: all six Bronze fingerprints unchanged.',flush=True)

if __name__=='__main__': main()
