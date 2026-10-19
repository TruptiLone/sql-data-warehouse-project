#!/usr/bin/env python3
"""Execute SELECT bodies only; no persistent Gold DDL. Run from repository root."""
import importlib.util
import sys
from pathlib import Path
sys.dont_write_bytecode=True
here=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('connection',here.parent/'bronze'/'load_bronze.py')
connection=importlib.util.module_from_spec(spec);spec.loader.exec_module(connection)
def select(file,label):
    return (here/file).read_text().split(f'-- BEGIN {label} SELECT\n')[1].split(f'-- END {label} SELECT')[0]
def main():
    connection.verify_container()
    old=(here/'preview_star.sql').read_text()
    # Reuse read-only safety preflight and stable-source locks, not provisional SELECTs.
    sql=old[:old.index(' SELECT ROW_NUMBER()')]
    for file,label,temp in [('view_customers.sql','CUSTOMER','#customers'),('view_products.sql','PRODUCT','#products'),('view_sales.sql','SALES','#sales')]:
        query=select(file,label).replace('gold.dim_customers','#customers').replace('gold.dim_products','#products')
        sql+=f'\nSELECT * INTO {temp} FROM (\n{query}\n) AS expected;\n'
    course=(here/'reference_customers_select.sql').read_text()
    sql+='SELECT * INTO #course_customers FROM (\n'+course+'\n) AS course;\n'
    sql+=(here/'quality_views.sql').read_text()
    print(connection.sql(sql))
if __name__=='__main__': main()
