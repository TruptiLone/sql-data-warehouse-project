"""Validate captured monthly metrics and plot them without database access."""
import argparse
import csv
from datetime import datetime
from decimal import Decimal
from pathlib import Path


def load_snapshot(path):
    with path.open(newline='', encoding='utf-8') as source:
        raw = list(csv.DictReader(source))
    rows = [{k: datetime.strptime(v, '%Y-%m-%d') if k == 'sales_month' else Decimal(v) for k, v in row.items()} for row in raw]
    expected = [(2010, 12)] + [(y, m) for y in range(2011, 2014) for m in range(1, 13)] + [(2014, 1)]
    if [(r['sales_month'].year, r['sales_month'].month) for r in rows] != expected or any(r['sales_month'].day != 1 for r in rows):
        raise ValueError('Expected 38 consecutive month-start observations')
    total = Decimal(0)
    prices = Decimal(0)
    tolerance = Decimal('0.000001')
    for i, row in enumerate(rows):
        if any(not value.is_finite() for key, value in row.items() if key != 'sales_month'):
            raise ValueError('Nonfinite metric')
        total += row['total_sales']
        prices += row['average_unit_price']
        moving = sum(r['total_sales'] for r in rows[max(0, i - 2):i + 1]) / Decimal(min(i + 1, 3))
        if row['running_total_sales'] != total:
            raise ValueError(f'Running total mismatch at row {i + 1}')
        if abs(moving - row['three_month_moving_average_sales']) > tolerance:
            raise ValueError(f'Moving average mismatch at row {i + 1}')
        if abs(prices / Decimal(i + 1) - row['cumulative_average_monthly_price']) > tolerance:
            raise ValueError(f'Expanding price mismatch at row {i + 1}')
    if total != Decimal('29351258'):
        raise ValueError('Final total differs from published checkpoint')
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--csv', type=Path, default=Path(__file__).resolve().parents[1] / 'data/cumulative_analysis_snapshot.csv')
    parser.add_argument('--output-dir', type=Path, required=True)
    args = parser.parse_args()
    rows = load_snapshot(args.csv)
    names = ['cumulative_sales_trend.png', 'monthly_sales_moving_average.png', 'average_price_cumulative_average.png']
    targets = [args.output_dir / name for name in names]
    if any(p.exists() for p in targets):
        raise FileExistsError('Choose a fresh output directory; existing images are preserved')
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    import matplotlib.dates as mdates
    from matplotlib.ticker import FuncFormatter
    plt.rcParams.update({'font.size': 11, 'axes.spines.top': False, 'axes.spines.right': False})
    dates = [r['sales_month'] for r in rows]
    configs = [
        ('Cumulative Recorded Sales', [('running_total_sales', 'All-period cumulative sales')], 'Recorded sales amount', 'Boundary-year coverage: December 2010 only; January 2014 only.'),
        ('Monthly Sales and Three-Month Moving Average', [('total_sales', 'Monthly sales'), ('three_month_moving_average_sales', 'Three-month moving average')], 'Recorded sales amount', 'Smoothing uses 1, then 2, then 3 available rows. January 2014 alone does not establish a sustained decline.'),
        ('Monthly Average Price and Expanding Average', [('average_unit_price', 'Monthly average unit price'), ('cumulative_average_monthly_price', 'Equally weighted expanding monthly average')], 'Recorded price amount', 'Expanding average weights months equally, not transactions. Product-mix effects are hypotheses, not verified causes.')
    ]
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for index, (title, series, ylabel, caption) in enumerate(configs):
        fig, ax = plt.subplots(figsize=(13, 7), layout='constrained')
        for j, (column, label) in enumerate(series):
            ax.plot(dates, [float(r[column]) for r in rows], label=label, color=['#2878b5', '#c66a20'][j], linestyle=['-', '--'][j], marker='o' if j == 0 else None, markersize=3)
        ax.set_title('RetailFlow 360 — ' + title, pad=16)
        ax.set_ylabel(ylabel + ' (currency unconfirmed)')
        ax.xaxis.set_major_locator(mdates.MonthLocator(bymonth=[1, 7]))
        ax.xaxis.set_major_formatter(mdates.DateFormatter('%Y-%m'))
        plt.setp(ax.get_xticklabels(), rotation=30, ha='right')
        ax.set_ylim(bottom=0)
        ax.grid(alpha=.2)
        ax.legend(loc='upper right' if index == 2 else 'upper left', fontsize=10)
        if index < 2:
            ax.yaxis.set_major_formatter(FuncFormatter(lambda v, _: f'{v / 1e6:g}M'))
        else:
            ax.yaxis.set_major_formatter(FuncFormatter(lambda v, _: f'{v:,.0f}'))
        if index == 0:
            ax.annotate('Final: 29,351,258', (dates[-1], float(rows[-1]['running_total_sales'])), xytext=(-150, -35), textcoords='offset points', arrowprops={'arrowstyle': '->'})
        ax.set_xlabel(caption + '\nSource: RetailFlow 360 Gold SQL exports | Partial boundary years: 2010 and 2014', labelpad=12, fontsize=10)
        with targets[index].open('xb') as output:
            fig.savefig(output, format='png', dpi=160)
        plt.close(fig)
    print('PASS: 38 months; cumulative and average checks; final sales 29,351,258. Charts:', *targets)


if __name__ == '__main__':
    main()
