#!/usr/bin/env python3
"""Preview only: no apply option and no persistent DDL/DML."""
import argparse
import importlib.util
import sys
from pathlib import Path
sys.dont_write_bytecode=True
here=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('connection',here.parent/'bronze'/'load_bronze.py')
connection=importlib.util.module_from_spec(spec);spec.loader.exec_module(connection)
if __name__=='__main__':
    argparse.ArgumentParser(description=__doc__).parse_args()
    definition=(here/'view_customers.sql').read_text()
    select=definition.split('-- BEGIN CUSTOMER SELECT\n',1)[1].split('-- END CUSTOMER SELECT',1)[0]
    text=(here/'quality_customers.sql').read_text().replace('$(customer_select)',select)
    connection.verify_container()
    print(connection.sql(text))
