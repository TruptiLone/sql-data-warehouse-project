"""Validate Query 1 JSON/CSV and derive performance metrics without SQL execution."""
import argparse
import csv
import json
from collections import defaultdict, Counter
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

BASE = ['order_year', 'product_key', 'product_name', 'current_sales']
EXTRA = ['average_annual_sales', 'difference_vs_average', 'average_performance_status', 'previous_observed_year', 'previous_observed_sales', 'previous_year_sales', 'year_over_year_difference', 'year_over_year_change_pct', 'year_over_year_status']


def calculate(source):
    if source.suffix.lower() == '.csv':
        with source.open(newline='', encoding='utf-8') as f:
            raw = list(csv.DictReader(f))
    else:
        raw = json.loads(source.read_text(encoding='utf-8-sig'), parse_float=Decimal)
    rows = []
    for x in raw:
        if not set(BASE).issubset(x) or any(x[k] is None for k in BASE):
            raise ValueError('Missing source field')
        y, key = Decimal(str(x['order_year'])), Decimal(str(x['product_key']))
        sale = Decimal(str(x['current_sales']))
        if not y.is_finite() or not key.is_finite() or y != y.to_integral_value() or key != key.to_integral_value() or key <= 0:
            raise ValueError('Invalid identifier/year')
        if not sale.is_finite() or sale != sale.quantize(Decimal('.01')) or not str(x['product_name']).strip():
            raise ValueError('Invalid sales/name')
        rows.append(dict(order_year=int(y), product_key=int(key), product_name=x['product_name'], current_sales=sale))
    rows.sort(key=lambda r: (r['product_key'], r['order_year']))
    groups = defaultdict(list)
    for row in rows:
        groups[row['product_key']].append(row)
    if len(rows) != 219 or len(groups) != 130 or len({(r['product_key'], r['order_year']) for r in rows}) != 219:
        raise ValueError('Row/product/uniqueness check failed')
    if Counter(r['order_year'] for r in rows) != {2011: 37, 2012: 80, 2013: 102}:
        raise ValueError('Unexpected year coverage')
    totals = {y: sum(r['current_sales'] for r in rows if r['order_year'] == y) for y in [2011, 2012, 2013]}
    if totals != {2011: Decimal('7075088'), 2012: Decimal('5842231'), 2013: Decimal('16344878')}:
        raise ValueError('Annual totals mismatch')
    derived = []
    for group in groups.values():
        if len({r['product_name'] for r in group}) != 1:
            raise ValueError('Inconsistent names for product key')
        average = sum(r['current_sales'] for r in group) / Decimal(len(group))
        prior = None
        for row in group:
            delta = row['current_sales'] - average
            comparable = prior is not None and prior['order_year'] == row['order_year'] - 1
            difference = row['current_sales'] - prior['current_sales'] if comparable else None
            pct = difference / prior['current_sales'] * 100 if comparable and prior['current_sales'] != 0 else None
            status = 'No Prior Year' if prior is None else 'Missing Prior Calendar Year' if not comparable else 'Increase' if difference > 0 else 'Decrease' if difference < 0 else 'No Change'
            derived.append({**row, 'average_annual_sales': average, 'difference_vs_average': delta, 'average_performance_status': 'Above Average' if delta > 0 else 'Below Average' if delta < 0 else 'At Average', 'previous_observed_year': prior['order_year'] if prior else None, 'previous_observed_sales': prior['current_sales'] if prior else None, 'previous_year_sales': prior['current_sales'] if comparable else None, 'year_over_year_difference': difference, 'year_over_year_change_pct': pct, 'year_over_year_status': status})
            prior = row
    comparable = [r for r in derived if r['order_year'] == 2013 and r['previous_year_sales'] is not None]
    if len(comparable) != 65 or Counter(r['year_over_year_status'] for r in comparable) != {'Increase': 62, 'Decrease': 3}:
        raise ValueError('Comparable product results mismatch')
    example = [r for r in derived if r['product_key'] == 120]
    if [r['current_sales'] for r in example] != list(map(Decimal, ['4098', '342921', '945540'])) or any(r['average_annual_sales'] != 430853 for r in example):
        raise ValueError('Product 120 checkpoint failed')
    if example[1]['year_over_year_difference'] != 338823 or example[2]['year_over_year_difference'] != 602619 or example[2]['difference_vs_average'] != 514687:
        raise ValueError('Product 120 derived checkpoints failed')
    return rows, derived


def write_csv(path, columns, rows):
    with path.open('x', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=columns, lineterminator='\n')
        writer.writeheader()
        for row in rows:
            writer.writerow({k: '' if row[k] is None else format(row[k].quantize(Decimal('.000001'), rounding=ROUND_HALF_UP), 'f') if isinstance(row[k], Decimal) and k in ['average_annual_sales', 'difference_vs_average', 'year_over_year_change_pct'] else row[k] for k in columns})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=Path(__file__).resolve().parents[1] / 'data/yearly_product_sales_snapshot.csv')
    parser.add_argument('--output-dir', type=Path, required=True)
    args = parser.parse_args()
    rows, derived = calculate(args.source)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    targets = [args.output_dir / n for n in ['yearly_product_sales_snapshot.csv', 'product_performance_snapshot.csv']]
    if any(p.exists() for p in targets):
        raise FileExistsError('Use a fresh output directory; existing datasets are preserved')
    write_csv(targets[0], BASE, rows)
    write_csv(targets[1], BASE + EXTRA, derived)
    print('PASS: 219 rows, 130 products; total 29,262,197; 65 comparisons: 62 increases, 3 decreases; product 120 checkpoints.')


if __name__ == '__main__':
    main()
