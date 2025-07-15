#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Plot performance table from markdown file.
Generates a single visualization with 3 stacked heatmaps.
"""

import argparse
import re
from pathlib import Path
import pandas as pd
import matplotlib.pyplot as plt


def parse_markdown_table(file_path: str) -> pd.DataFrame:
    """Parse the markdown table and extract performance data."""
    with open(file_path, "r") as f:
        lines = f.readlines()

    # Find header lines
    header_line = None
    subheader_line = None
    separator_line = None

    for i, line in enumerate(lines):
        if "Model" in line and "C" in line:
            header_line = i
        elif "Correct | Semantic | Conflict" in line:
            subheader_line = i
        elif "---" in line and header_line is not None:
            separator_line = i
            break

    if header_line is None or subheader_line is None or separator_line is None:
        raise ValueError("Could not find table structure in markdown file")

    # Extract language names from header
    header = lines[header_line].strip()

    # Split by pipes and extract non-empty language names
    header_parts = [part.strip() for part in header.split("|")]

    languages = []
    for part in header_parts[1:]:  # Skip "Model"
        if part and part not in ["", " ", "Model"] and not part.isspace():
            # Only add if it looks like a language name (has letters)
            if re.match(r"^[A-Za-z#+]+$", part):
                languages.append(part)

    # Remove duplicates while preserving order
    seen = set()
    unique_languages = []
    for lang in languages:
        if lang not in seen:
            seen.add(lang)
            unique_languages.append(lang)

    languages = unique_languages
    print(f"Found {len(languages)} languages: {', '.join(languages)}")

    # Parse data rows
    data_rows = []
    for i in range(separator_line + 1, len(lines)):
        line = lines[i].strip()
        if not line or not line.startswith("|"):
            break

        # Split by pipes and clean up
        parts = [
            part.strip() for part in line.split("|")[1:-1]
        ]  # Remove empty first/last
        if len(parts) == 0:
            continue

        model_name = parts[0]
        if not model_name:
            continue

        # Extract metrics (expecting 3 metrics per language)
        metrics = parts[1:]
        data_rows.append([model_name] + metrics)

    # Create DataFrame
    columns = ["Model"]
    for lang in languages:
        columns.extend([f"{lang}_Correct", f"{lang}_Semantic", f"{lang}_Conflict"])

    df = pd.DataFrame(data_rows, columns=columns[: len(data_rows[0])])

    # Convert percentage strings to floats
    for col in df.columns[1:]:  # Skip Model column
        df[col] = df[col].str.replace("%", "").str.replace("--", "0").astype(float)

    return df


def create_combined_bar_charts(df: pd.DataFrame, output_dir: Path) -> None:
    """Create a single plot with 3 stacked bar charts for all metrics."""

    # Set up the figure with 3 subplots stacked vertically
    fig, axes = plt.subplots(3, 1, figsize=(16, 18))

    metrics = ["Correct", "Semantic", "Conflict"]
    titles = ["Correct Merges (%)", "Semantic Merges (%)", "Conflict Detection (%)"]
    colors = ["#2E8B57", "#4169E1", "#DC143C"]  # Green, Blue, Red

    for i, (metric, title, color) in enumerate(zip(metrics, titles, colors)):
        # Extract columns for the specific metric
        metric_cols = [col for col in df.columns if col.endswith(f"_{metric}")]
        if not metric_cols:
            print(f"No columns found for metric: {metric}")
            continue

        # Create pivot table - transpose so languages are on x-axis
        bar_data = df[["Model"] + metric_cols].set_index("Model")
        bar_data.columns = [col.replace(f"_{metric}", "") for col in bar_data.columns]
        bar_data = bar_data.T  # Transpose: languages as rows, models as columns

        # Create grouped bar chart
        bar_data.plot(kind="bar", ax=axes[i], width=0.8)

        axes[i].set_title(
            f"Model Performance - {title}", fontsize=16, fontweight="bold"
        )
        axes[i].set_xlabel("Programming Languages", fontsize=12)
        axes[i].set_ylabel("Percentage (%)", fontsize=12)
        axes[i].legend(title="Models", bbox_to_anchor=(1.05, 1), loc="upper left")
        axes[i].grid(True, alpha=0.3)

        # Rotate x-axis labels for better readability
        axes[i].tick_params(axis="x", rotation=45)

        # Set y-axis limits for better comparison
        axes[i].set_ylim(0, 100)

    # Adjust layout to prevent overlap
    plt.tight_layout()

    # Save the combined plot
    output_file = output_dir / "performance_bar_charts.png"
    plt.savefig(output_file, dpi=300, bbox_inches="tight")
    plt.close()
    print(f"Saved combined bar charts: {output_file}")


def main():
    parser = argparse.ArgumentParser(
        description="Plot performance table from markdown file"
    )
    parser.add_argument(
        "--input",
        type=str,
        default="tables/results_table.md",
        help="Input markdown table file",
    )
    parser.add_argument(
        "--output_dir", type=str, default="tables", help="Output directory for plots"
    )

    args = parser.parse_args()

    input_file = Path(args.input)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(exist_ok=True)

    if not input_file.exists():
        print(f"Error: Input file {input_file} not found")
        return

    print(f"Parsing markdown table from: {input_file}")
    df = parse_markdown_table(str(input_file))
    print(f"Parsed data shape: {df.shape}")
    print(f"Models: {df['Model'].tolist()}")

    # Generate single combined visualization
    print("\nGenerating combined bar charts...")
    create_combined_bar_charts(df, output_dir)

    print(f"\nPlot saved to: {output_dir}")


if __name__ == "__main__":
    main()
