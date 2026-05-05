#!/usr/bin/env python3
import csv
import math
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

RESULT_ROOT = Path('src/lennard-jones/results/20260504_131723')
ANALYSIS_DIR = RESULT_ROOT / 'analysis'
OUT_DIR = Path('report')
GEN_DIR = OUT_DIR / 'generated'
FIG_DIR = OUT_DIR / 'figures'

GEN_DIR.mkdir(parents=True, exist_ok=True)
FIG_DIR.mkdir(parents=True, exist_ok=True)


def read_csv(path):
    with path.open(newline='', encoding='utf-8') as f:
        return list(csv.DictReader(f))


basic_rows = read_csv(ANALYSIS_DIR / 'basic_summary.csv')
block_rows = read_csv(ANALYSIS_DIR / 'block_sweep_summary.csv')
raw_rows = read_csv(ANALYSIS_DIR / 'raw_results.csv')

# Convert numeric fields where useful
for row in basic_rows:
    for key in ['particles', 'steps', 'cpu_runs', 'gpu_runs', 'gpu_block_size']:
        row[key] = int(row[key])
    for key in ['cpu_mean_s', 'cpu_stddev_s', 'cpu_mean_abs_delta_total', 'gpu_mean_s', 'gpu_stddev_s', 'gpu_mean_abs_delta_total', 'speedup']:
        row[key] = float(row[key])

for row in block_rows:
    for key in ['particles', 'steps', 'gpu_block_size', 'runs']:
        row[key] = int(row[key])
    for key in ['mean_time_s', 'stddev_time_s', 'min_time_s', 'max_time_s', 'mean_abs_delta_total']:
        row[key] = float(row[key])

for row in raw_rows:
    for key in ['particles', 'steps', 'seed', 'log_energies', 'gpu_block_size']:
        if row[key] != '':
            row[key] = int(row[key])
    for key in ['density', 'temperature', 'box_size', 'time_seconds', 'start_ke', 'start_pe', 'start_total', 'final_ke', 'final_pe', 'final_total', 'delta_total']:
        if row[key] != '':
            row[key] = float(row[key])

basic_rows.sort(key=lambda r: r['particles'])

# Relative energy drift for the basic runs actually used in the report.
rel_drift = {}
for row in raw_rows:
    if row['category'] != 'basic':
        continue
    if row['device'] == 'cpu':
        key = ('cpu', row['particles'])
        rel_drift.setdefault(key, []).append(abs(row['delta_total']) / abs(row['start_total']))
    elif row['device'] == 'gpu' and row['gpu_block_size'] == 128:
        key = ('gpu', row['particles'])
        rel_drift.setdefault(key, []).append(abs(row['delta_total']) / abs(row['start_total']))

rel_drift_summary = {}
for key, values in rel_drift.items():
    rel_drift_summary[key] = sum(values) / len(values)

max_rel_drift = max(rel_drift_summary.values())

# Power-law fits y = a * x^b on the reported CPU/GPU means.

def power_fit(xs, ys):
    lx = [math.log(x) for x in xs]
    ly = [math.log(y) for y in ys]
    n = len(xs)
    mx = sum(lx) / n
    my = sum(ly) / n
    b = sum((x - mx) * (y - my) for x, y in zip(lx, ly)) / sum((x - mx) ** 2 for x in lx)
    a = math.exp(my - b * mx)
    return a, b

particles = [row['particles'] for row in basic_rows]
cpu_means = [row['cpu_mean_s'] for row in basic_rows]
gpu_means = [row['gpu_mean_s'] for row in basic_rows]
speedups = [row['speedup'] for row in basic_rows]

cpu_a, cpu_b = power_fit(particles, cpu_means)
gpu_a, gpu_b = power_fit(particles, gpu_means)

# Local doubling ratios for the text.
cpu_ratios = []
gpu_ratios = []
speedup_ratios = []
for i in range(1, len(particles)):
    cpu_ratios.append(cpu_means[i] / cpu_means[i - 1])
    gpu_ratios.append(gpu_means[i] / gpu_means[i - 1])
    speedup_ratios.append(speedups[i] / speedups[i - 1])

cpu_ratio_min, cpu_ratio_max = min(cpu_ratios), max(cpu_ratios)
gpu_ratio_min, gpu_ratio_max = min(gpu_ratios), max(gpu_ratios)
speedup_ratio_min, speedup_ratio_max = min(speedup_ratios), max(speedup_ratios)

# Generate table 1: block-size sweep
block_by_particle = {}
for row in block_rows:
    block_by_particle.setdefault(row['particles'], {})[row['gpu_block_size']] = row['mean_time_s']

block_sizes = [64, 128, 256, 512, 1024]
with (GEN_DIR / 'table_block_sweep.tex').open('w', encoding='utf-8') as f:
    f.write('\\begin{tabular}{rccccc}\\toprule\n')
    f.write('$N$ & 64 & 128 & 256 & 512 & 1024 \\\\ \\midrule\n')
    for n in sorted(block_by_particle):
        values = [block_by_particle[n][b] for b in block_sizes]
        best = min(values)
        cells = []
        for b in block_sizes:
            val = block_by_particle[n][b]
            text = f'{val:.3f}'
            if abs(val - best) < 1e-12:
                text = f'\\textbf{{{text}}}'
            cells.append(text)
        f.write(f'{n} & ' + ' & '.join(cells) + ' \\\\ \n')
    f.write('\\bottomrule\\end{tabular}\n')

# Generate table 2: final CPU vs GPU comparison
with (GEN_DIR / 'table_basic_summary.tex').open('w', encoding='utf-8') as f:
    f.write('\\begin{tabular}{rccc}\\toprule\n')
    f.write('$N$ & CPU time [s] & GPU time [s] & Speed-up \\\\ \\midrule\n')
    for row in basic_rows:
        cpu_text = f"{row['cpu_mean_s']:.3f} $\\pm$ {row['cpu_stddev_s']:.3f}"
        gpu_text = f"{row['gpu_mean_s']:.3f} $\\pm$ {row['gpu_stddev_s']:.3f}"
        f.write(f"{row['particles']} & {cpu_text} & {gpu_text} & ${row['speedup']:.2f}\\times$ \\\\ \n")
    f.write('\\bottomrule\\end{tabular}\n')

# Generate figure: runtime scaling and speedup trend
fit_x = [1000, 2000, 4000, 8000]
fit_cpu = [cpu_a * (x ** cpu_b) for x in fit_x]
fit_gpu = [gpu_a * (x ** gpu_b) for x in fit_x]

fig, axes = plt.subplots(1, 2, figsize=(10.5, 4.2))

ax = axes[0]
ax.plot(particles, cpu_means, 'o-', label='CPU mean time')
ax.plot(fit_x, fit_cpu, '--', label=fr'CPU fit $\propto N^{{{cpu_b:.2f}}}$')
ax.plot(particles, gpu_means, 's-', label='GPU mean time (block 128)')
ax.plot(fit_x, fit_gpu, '--', label=fr'GPU fit $\propto N^{{{gpu_b:.2f}}}$')
ax.set_xscale('log', base=2)
ax.set_yscale('log')
ax.set_xlabel('Particles $N$')
ax.set_ylabel('Mean time [s]')
ax.set_title('Measured scaling for 5000 steps')
ax.grid(True, which='both', alpha=0.3)
ax.legend(fontsize=8)

ax = axes[1]
ax.plot(particles, speedups, 'o-', color='tab:green')
ax.set_xscale('log', base=2)
ax.set_xlabel('Particles $N$')
ax.set_ylabel('Speed-up $S=t_{CPU}/t_{GPU}$')
ax.set_title('Speed-up grows with problem size')
ax.grid(True, which='both', alpha=0.3)
for x, y in zip(particles, speedups):
    ax.annotate(f'{y:.1f}x', (x, y), textcoords='offset points', xytext=(0, 6), ha='center', fontsize=8)

fig.tight_layout()
for ext in ['pdf', 'png']:
    fig.savefig(FIG_DIR / f'scaling_and_speedup.{ext}', bbox_inches='tight')
plt.close(fig)

# Write derived values for the report text.
with (GEN_DIR / 'report_values.tex').open('w', encoding='utf-8') as f:
    f.write(f'\\newcommand{{\\BestBlockSize}}{{128}}\n')
    f.write(f'\\newcommand{{\\CpuFitExponent}}{{{cpu_b:.2f}}}\n')
    f.write(f'\\newcommand{{\\GpuFitExponent}}{{{gpu_b:.2f}}}\n')
    mantissa, exponent = f'{max_rel_drift:.2e}'.split('e')
    exponent = int(exponent)
    f.write(f'\\newcommand{{\\MaxRelDrift}}{{${mantissa}\\times 10^{{{exponent}}}$}}\n')
    f.write(f'\\newcommand{{\\CpuDoublingMin}}{{{cpu_ratio_min:.2f}}}\n')
    f.write(f'\\newcommand{{\\CpuDoublingMax}}{{{cpu_ratio_max:.2f}}}\n')
    f.write(f'\\newcommand{{\\GpuDoublingMin}}{{{gpu_ratio_min:.2f}}}\n')
    f.write(f'\\newcommand{{\\GpuDoublingMax}}{{{gpu_ratio_max:.2f}}}\n')
    f.write(f'\\newcommand{{\\SpeedupDoublingMin}}{{{speedup_ratio_min:.2f}}}\n')
    f.write(f'\\newcommand{{\\SpeedupDoublingMax}}{{{speedup_ratio_max:.2f}}}\n')

print('Generated report assets in', OUT_DIR)
