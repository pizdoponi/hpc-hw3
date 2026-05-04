#!/usr/bin/env python3
import argparse
import csv
import math
import os
import statistics
from collections import defaultdict
from pathlib import Path


INT_FIELDS = {"particles", "steps", "seed", "log_energies", "gpu_block_size"}
FLOAT_FIELDS = {
    "density",
    "temperature",
    "box_size",
    "time_seconds",
    "start_ke",
    "start_pe",
    "start_total",
    "final_ke",
    "final_pe",
    "final_total",
    "delta_total",
}


def parse_result_line(line: str):
    if not line.startswith("RESULT "):
        return None

    result = {}
    for token in line.strip().split()[1:]:
        if "=" not in token:
            continue
        key, value = token.split("=", 1)
        result[key] = value

    for key in INT_FIELDS:
        if key in result:
            result[key] = int(result[key])
    for key in FLOAT_FIELDS:
        if key in result:
            result[key] = float(result[key])
    return result


def parse_log_file(path: Path):
    result = None
    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            parsed = parse_result_line(line)
            if parsed is not None:
                result = parsed
    return result


def classify_result(relative_parts):
    if "block-sweep" in relative_parts:
        return "block_sweep"
    if "basic" in relative_parts:
        return "basic"
    if "energy" in relative_parts:
        return "energy"
    if "visualization" in relative_parts:
        return "visualization"
    return "other"


def compute_stats(values):
    if not values:
        return None
    if len(values) == 1:
        stddev = 0.0
    else:
        stddev = statistics.stdev(values)
    return {
        "runs": len(values),
        "mean": statistics.mean(values),
        "stddev": stddev,
        "min": min(values),
        "max": max(values),
    }


def fmt(value, digits=6):
    if value is None:
        return "N/A"
    if isinstance(value, int):
        return str(value)
    return f"{value:.{digits}f}"


def write_csv(path: Path, rows, fieldnames):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def write_markdown_table(path: Path, title: str, rows, columns):
    with path.open("w", encoding="utf-8") as handle:
        handle.write(f"# {title}\n\n")
        handle.write("| " + " | ".join(name for name, _ in columns) + " |\n")
        handle.write("| " + " | ".join("---" for _ in columns) + " |\n")
        for row in rows:
            handle.write("| " + " | ".join(str(row.get(key, "")) for _, key in columns) + " |\n")


def main():
    parser = argparse.ArgumentParser(description="Analyze Lennard-Jones benchmark logs.")
    parser.add_argument("--result-root", required=True, help="Directory that contains one benchmark run tree")
    parser.add_argument("--output-dir", required=True, help="Directory for generated summaries")
    args = parser.parse_args()

    result_root = Path(args.result_root).resolve()
    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    raw_rows = []
    for log_path in sorted(result_root.rglob("*.log")):
        parsed = parse_log_file(log_path)
        if parsed is None:
            continue
        rel_parts = log_path.relative_to(result_root).parts
        row = dict(parsed)
        row["category"] = classify_result(rel_parts)
        row["relative_log_path"] = str(log_path.relative_to(result_root))
        raw_rows.append(row)

    raw_fieldnames = [
        "category",
        "relative_log_path",
        "device",
        "particles",
        "steps",
        "density",
        "temperature",
        "seed",
        "log_energies",
        "gpu_block_size",
        "box_size",
        "time_seconds",
        "start_ke",
        "start_pe",
        "start_total",
        "final_ke",
        "final_pe",
        "final_total",
        "delta_total",
        "final_state",
    ]
    write_csv(output_dir / "raw_results.csv", raw_rows, raw_fieldnames)

    block_sweep_groups = defaultdict(list)
    basic_cpu_groups = defaultdict(list)
    basic_gpu_groups = defaultdict(list)

    for row in raw_rows:
        if row["category"] == "block_sweep":
            key = (row["particles"], row["steps"], row["gpu_block_size"])
            block_sweep_groups[key].append(row)
        elif row["category"] == "basic":
            if row["device"] == "cpu":
                key = (row["particles"], row["steps"])
                basic_cpu_groups[key].append(row)
            elif row["device"] == "gpu":
                key = (row["particles"], row["steps"], row["gpu_block_size"])
                basic_gpu_groups[key].append(row)

    block_rows_csv = []
    for (particles, steps, block_size), rows in sorted(block_sweep_groups.items()):
        times = [row["time_seconds"] for row in rows]
        drift = [abs(row["delta_total"]) for row in rows]
        stats = compute_stats(times)
        drift_stats = compute_stats(drift)
        block_rows_csv.append(
            {
                "particles": particles,
                "steps": steps,
                "gpu_block_size": block_size,
                "runs": stats["runs"],
                "mean_time_s": f"{stats['mean']:.6f}",
                "stddev_time_s": f"{stats['stddev']:.6f}",
                "min_time_s": f"{stats['min']:.6f}",
                "max_time_s": f"{stats['max']:.6f}",
                "mean_abs_delta_total": f"{drift_stats['mean']:.6f}",
            }
        )

    write_csv(
        output_dir / "block_sweep_summary.csv",
        block_rows_csv,
        [
            "particles",
            "steps",
            "gpu_block_size",
            "runs",
            "mean_time_s",
            "stddev_time_s",
            "min_time_s",
            "max_time_s",
            "mean_abs_delta_total",
        ],
    )

    block_rows_md = list(block_rows_csv)
    write_markdown_table(
        output_dir / "block_sweep_summary.md",
        "GPU block-size sweep summary",
        block_rows_md,
        [
            ("Particles", "particles"),
            ("Steps", "steps"),
            ("Block size", "gpu_block_size"),
            ("Runs", "runs"),
            ("Mean time [s]", "mean_time_s"),
            ("Stddev [s]", "stddev_time_s"),
            ("Min [s]", "min_time_s"),
            ("Max [s]", "max_time_s"),
            ("Mean |ΔE|", "mean_abs_delta_total"),
        ],
    )

    best_block_rows = []
    per_particle_blocks = defaultdict(list)
    for row in block_rows_csv:
        per_particle_blocks[(int(row["particles"]), int(row["steps"]))].append(row)

    for (particles, steps), rows in sorted(per_particle_blocks.items()):
        best = min(rows, key=lambda item: float(item["mean_time_s"]))
        best_block_rows.append(
            {
                "particles": particles,
                "steps": steps,
                "best_gpu_block_size": best["gpu_block_size"],
                "mean_time_s": best["mean_time_s"],
                "stddev_time_s": best["stddev_time_s"],
                "runs": best["runs"],
            }
        )

    write_csv(
        output_dir / "block_sweep_best_by_particle.csv",
        best_block_rows,
        ["particles", "steps", "best_gpu_block_size", "mean_time_s", "stddev_time_s", "runs"],
    )
    write_markdown_table(
        output_dir / "block_sweep_best_by_particle.md",
        "Best GPU block size by particle count",
        best_block_rows,
        [
            ("Particles", "particles"),
            ("Steps", "steps"),
            ("Best block size", "best_gpu_block_size"),
            ("Mean time [s]", "mean_time_s"),
            ("Stddev [s]", "stddev_time_s"),
            ("Runs", "runs"),
        ],
    )

    basic_summary_rows = []
    all_basic_keys = sorted({*basic_cpu_groups.keys(), *((p, s) for (p, s, _) in basic_gpu_groups.keys())})
    for particles, steps in all_basic_keys:
        cpu_rows = basic_cpu_groups.get((particles, steps), [])
        matching_gpu_keys = sorted(
            [key for key in basic_gpu_groups.keys() if key[0] == particles and key[1] == steps],
            key=lambda item: item[2],
        )
        gpu_rows = basic_gpu_groups.get(matching_gpu_keys[0], []) if matching_gpu_keys else []

        cpu_stats = compute_stats([row["time_seconds"] for row in cpu_rows])
        gpu_stats = compute_stats([row["time_seconds"] for row in gpu_rows])
        cpu_drift = compute_stats([abs(row["delta_total"]) for row in cpu_rows]) if cpu_rows else None
        gpu_drift = compute_stats([abs(row["delta_total"]) for row in gpu_rows]) if gpu_rows else None
        block_size = matching_gpu_keys[0][2] if matching_gpu_keys else "N/A"
        speedup = None
        if cpu_stats is not None and gpu_stats is not None and gpu_stats["mean"] != 0.0:
            speedup = cpu_stats["mean"] / gpu_stats["mean"]

        basic_summary_rows.append(
            {
                "particles": particles,
                "steps": steps,
                "cpu_runs": cpu_stats["runs"] if cpu_stats else 0,
                "cpu_mean_s": fmt(cpu_stats["mean"] if cpu_stats else None),
                "cpu_stddev_s": fmt(cpu_stats["stddev"] if cpu_stats else None),
                "cpu_mean_abs_delta_total": fmt(cpu_drift["mean"] if cpu_drift else None),
                "gpu_block_size": block_size,
                "gpu_runs": gpu_stats["runs"] if gpu_stats else 0,
                "gpu_mean_s": fmt(gpu_stats["mean"] if gpu_stats else None),
                "gpu_stddev_s": fmt(gpu_stats["stddev"] if gpu_stats else None),
                "gpu_mean_abs_delta_total": fmt(gpu_drift["mean"] if gpu_drift else None),
                "speedup": fmt(speedup),
            }
        )

    write_csv(
        output_dir / "basic_summary.csv",
        basic_summary_rows,
        [
            "particles",
            "steps",
            "cpu_runs",
            "cpu_mean_s",
            "cpu_stddev_s",
            "cpu_mean_abs_delta_total",
            "gpu_block_size",
            "gpu_runs",
            "gpu_mean_s",
            "gpu_stddev_s",
            "gpu_mean_abs_delta_total",
            "speedup",
        ],
    )
    write_markdown_table(
        output_dir / "basic_summary.md",
        "Basic benchmark summary",
        basic_summary_rows,
        [
            ("Particles", "particles"),
            ("Steps", "steps"),
            ("CPU runs", "cpu_runs"),
            ("CPU mean [s]", "cpu_mean_s"),
            ("CPU stddev [s]", "cpu_stddev_s"),
            ("GPU block size", "gpu_block_size"),
            ("GPU runs", "gpu_runs"),
            ("GPU mean [s]", "gpu_mean_s"),
            ("GPU stddev [s]", "gpu_stddev_s"),
            ("Speed-up", "speedup"),
        ],
    )

    with (output_dir / "report_snippets.md").open("w", encoding="utf-8") as handle:
        handle.write("# Report snippets\n\n")
        handle.write("## Basic benchmark summary\n\n")
        handle.write((output_dir / "basic_summary.md").read_text(encoding="utf-8"))
        handle.write("\n\n## Best GPU block size by particle count\n\n")
        handle.write((output_dir / "block_sweep_best_by_particle.md").read_text(encoding="utf-8"))
        handle.write("\n\n## Full GPU block-size sweep summary\n\n")
        handle.write((output_dir / "block_sweep_summary.md").read_text(encoding="utf-8"))

    print(f"Parsed {len(raw_rows)} result logs from {result_root}")
    print(f"Wrote analysis files to {output_dir}")


if __name__ == "__main__":
    main()
