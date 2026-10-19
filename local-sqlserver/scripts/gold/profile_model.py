#!/usr/bin/env python3
"""Read-only Gold design profile; never deploys Silver or Gold definitions."""
import importlib.util
import sys
from pathlib import Path
sys.dont_write_bytecode=True
here=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('bronze_connection',here.parent/'bronze'/'load_bronze.py')
connection=importlib.util.module_from_spec(spec)
spec.loader.exec_module(connection)
if __name__=='__main__':
    connection.verify_container()
    print(connection.sql((here/'profile_model.sql').read_text()))
