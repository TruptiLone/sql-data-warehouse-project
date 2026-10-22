"""Plot validated product-year results; derived values are Python calculations."""
import argparse
from pathlib import Path
from generate_performance_data import calculate


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=Path(__file__).resolve().parents[1] / 'data/yearly_product_sales_snapshot.csv')
    parser.add_argument('--output-dir', type=Path, required=True)
    args = parser.parse_args()
    rows, derived = calculate(args.source)
    names = ['products_with_sales_by_year.png', 'product_yoy_performance.png', 'product_average_vs_actual_sales.png']
    if any((args.output_dir / n).exists() for n in names):
        raise FileExistsError('Choose a fresh output directory')
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from matplotlib.ticker import FuncFormatter
    plt.rcParams.update({'font.size': 11, 'axes.spines.top': False, 'axes.spines.right': False})
    args.output_dir.mkdir(parents=True, exist_ok=True)
    def save(fig, name):
        with (args.output_dir / name).open('xb') as f:
            fig.savefig(f, format='png', dpi=170)
        plt.close(fig)
    fig, ax = plt.subplots(figsize=(10, 6), layout='constrained')
    counts = [sum(r['order_year'] == y for r in rows) for y in [2011, 2012, 2013]]
    bars = ax.bar(['2011', '2012', '2013'], counts, color='#2878b5')
    ax.bar_label(bars, padding=5)
    ax.set(title='RetailFlow 360 — Products with Recorded Sales', ylabel='Distinct product keys', ylim=(0, 115), xlabel='Observed sales coverage; not a count of product launches\nSource: exported SQL Query 1, 2011–2013')
    save(fig, names[0])
    comparable = [r for r in derived if r['order_year'] == 2013 and r['previous_year_sales'] is not None]
    winners = sorted([r for r in comparable if r['year_over_year_difference'] > 0], key=lambda r: (-r['year_over_year_difference'], r['product_key']))[:3]
    losers = sorted([r for r in comparable if r['year_over_year_difference'] < 0], key=lambda r: (r['year_over_year_difference'], r['product_key']))[:3]
    selected = winners + losers
    fig, ax = plt.subplots(figsize=(12, 7), layout='constrained')
    positions = list(range(len(selected)))
    ax.barh([p - .19 for p in positions], [float(r['previous_year_sales']) for r in selected], height=.36, label='2012', color='#2878b5')
    ax.barh([p + .19 for p in positions], [float(r['current_sales']) for r in selected], height=.36, label='2013', color='#167b68')
    ax.set_yticks(positions, [r['product_name'] + ' [' + str(r['product_key']) + ']' for r in selected]);ax.invert_yaxis()
    ax.xaxis.set_major_formatter(FuncFormatter(lambda v, _: f'{v/1e6:g}M'))
    ax.legend();ax.set(title='RetailFlow 360 — Selected Product YoY Sales', xlabel='Recorded sales amount (currency unconfirmed)\nThree largest absolute increases and all three decreases, 2012–2013\nSource: SQL Query 1 export; comparison/selection calculated in Python')
    save(fig, names[1])
    ex = [r for r in derived if r['product_key'] == 120]
    fig, ax = plt.subplots(figsize=(11, 6), layout='constrained')
    bars = ax.bar([str(r['order_year']) for r in ex], [float(r['current_sales']) for r in ex], color='#2878b5')
    ax.bar_label(bars, labels=[f"{r['current_sales']:,.0f}" for r in ex], padding=5)
    ax.axhline(float(ex[0]['average_annual_sales']), color='#c66a20', linestyle='--', label='Observed-year average: 430,853')
    ax.legend(loc='upper left');ax.set_ylim(0, 1100000)
    ax.yaxis.set_major_formatter(FuncFormatter(lambda v, _: f'{v/1e6:g}M'))
    ax.set(title='RetailFlow 360 — Mountain-200 Black- 38 [120]', ylabel='Recorded sales amount (currency unconfirmed)', xlabel='Benchmark equally weights the three observed sales years\nSource: SQL Query 1 export; benchmark calculated in Python')
    save(fig, names[2])
    print('Validated inputs and generated all three charts.')


if __name__ == '__main__':
    main()
