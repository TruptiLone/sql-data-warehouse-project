"""Regenerate equivalent sales plots from the captured CSV; no database access."""
import argparse
import csv
from collections import defaultdict
from datetime import datetime
from decimal import Decimal
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--csv', type=Path, default=Path(__file__).resolve().parents[1] / 'data/monthly_sales_snapshot.csv')
    parser.add_argument('--output-dir', type=Path, required=True)
    args = parser.parse_args()
    with args.csv.open(newline='', encoding='utf-8') as source:
        reader = csv.DictReader(source)
        if reader.fieldnames != ['sales_month', 'total_sales']:
            raise ValueError('Expected sales_month,total_sales columns')
        rows = [(datetime.strptime(r['sales_month'], '%Y-%m-%d'), Decimal(r['total_sales'])) for r in reader]
    expected_months = [(2010, 12)] + [(y, m) for y in range(2011, 2014) for m in range(1, 13)] + [(2014, 1)]
    if [(d.year, d.month) for d, _ in rows] != expected_months or any(d.day != 1 for d, _ in rows):
        raise ValueError('Expected 38 unique ordered monthly observations, December 2010–January 2014')
    if any(not v.is_finite() or v < 0 for _, v in rows):
        raise ValueError('Snapshot amounts must be finite and nonnegative')
    totals = defaultdict(Decimal)
    for d, value in rows:
        totals[d.year] += value
    expected = {2010: Decimal('43419'), 2011: Decimal('7075088'), 2012: Decimal('5842231'), 2013: Decimal('16344878'), 2014: Decimal('45642')}
    if dict(totals) != expected:
        raise ValueError(f'Annual reconciliation failed: {dict(totals)}')
    if max(rows, key=lambda row: row[1]) != (datetime(2013, 12, 1), Decimal('1874128')):
        raise ValueError('Peak month does not match the captured result')
    destinations = [args.output_dir / name for name in ('annual_sales_trend.png', 'monthly_sales_trend.png')]
    if any(p.exists() for p in destinations):
        raise FileExistsError('Choose a fresh output directory; existing charts will not be overwritten')

    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    import matplotlib.dates as mdates
    from matplotlib.ticker import FuncFormatter
    plt.rcParams.update({'font.size': 11, 'axes.spines.top': False, 'axes.spines.right': False})
    args.output_dir.mkdir(parents=True, exist_ok=True)
    fig, ax = plt.subplots(figsize=(11, 6), layout='constrained')
    bars = ax.bar(['2010*', '2011', '2012', '2013', '2014*'], [float(v) for v in totals.values()], color=['#93a9bd', '#2878b5', '#2878b5', '#167b68', '#93a9bd'])
    ax.bar_label(bars, labels=[f'{v:,.0f}' for v in totals.values()], padding=5, fontsize=10)
    ax.set(title='RetailFlow 360 — Annual Recorded Sales', ylabel='Recorded sales amount (currency unconfirmed)', ylim=(0, 19000000))
    ax.yaxis.set_major_formatter(FuncFormatter(lambda value, _: f'{value / 1e6:g}M'))
    ax.set_xlabel('*Partial coverage: December 2010 and January 2014 only\nSource: RetailFlow 360 Gold SQL query outputs')
    ax.grid(axis='y', alpha=.2); ax.set_axisbelow(True)
    with destinations[0].open('xb') as target:
        fig.savefig(target, format='png', dpi=180)
    plt.close(fig)
    full = [(d, float(v)) for d, v in rows if 2011 <= d.year <= 2013]
    fig, ax = plt.subplots(figsize=(12, 6), layout='constrained')
    ax.plot([d for d, _ in full], [v for _, v in full], color='#2878b5', marker='o', markersize=4)
    ax.set(title='RetailFlow 360 — Monthly Sales, 2011–2013', ylabel='Recorded sales amount (currency unconfirmed)', ylim=(0, 2100000))
    ax.xaxis.set_major_locator(mdates.MonthLocator(bymonth=[1, 4, 7, 10]))
    ax.xaxis.set_major_formatter(mdates.DateFormatter('%Y-%m'))
    plt.setp(ax.get_xticklabels(), rotation=35, ha='right')
    ax.yaxis.set_major_formatter(FuncFormatter(lambda value, _: f'{value / 1e6:g}M'))
    ax.annotate('Dec 2013: 1,874,128', xy=(full[-1][0], full[-1][1]), xytext=(-155, 25), textcoords='offset points', arrowprops={'arrowstyle': '->', 'color': '#167b68'})
    ax.set_xlabel('Source: RetailFlow 360 Gold SQL query outputs\nTwelve monthly observations per year; partial boundary years excluded from this plot')
    ax.grid(alpha=.2)
    with destinations[1].open('xb') as target:
        fig.savefig(target, format='png', dpi=180)
    plt.close(fig)
    print('Validated 38 months; annual totals reconcile to 29,351,258. Generated:', *destinations)


if __name__ == '__main__':
    main()
