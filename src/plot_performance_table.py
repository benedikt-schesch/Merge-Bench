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


def parse_markdown_table(file_path: str) -> pd.DataFrame:  # pylint: disable=too-many-branches
    """Parse the markdown table and extract performance data."""
    with open(file_path, "r", encoding="utf-8") as f:
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


def create_stacked_bar_chart(df: pd.DataFrame, output_dir: Path) -> None:  # pylint: disable=too-many-locals
    """Create a stacked bar chart with 4 segments for each model-language combination."""

    # Extract unique languages from column names
    languages = []
    for col in df.columns:
        if col.endswith("_Correct"):
            lang = col.replace("_Correct", "")
            languages.append(lang)

    # Set up the figure
    _, ax = plt.subplots(figsize=(20, 10))

    # Prepare data for stacking
    models = df["Model"].tolist()
    n_models = len(models)
    n_languages = len(languages)

    # Calculate the 4 segments for each model-language combination
    segment1_data = []  # Equivalent to developer (Correct)
    segment2_data = []  # Code Normalized Equivalent (Semantic - Correct)
    segment3_data = []  # Conflicts
    segment4_data = []  # Different from normalized (100 - Semantic - Conflict)

    for lang in languages:
        correct_col = f"{lang}_Correct"
        semantic_col = f"{lang}_Semantic"
        conflict_col = f"{lang}_Conflict"

        # Get values for this language
        correct_vals = df[correct_col].values
        semantic_vals = df[semantic_col].values
        conflict_vals = df[conflict_col].values

        # Calculate segments
        seg1 = correct_vals
        seg2 = semantic_vals - correct_vals
        seg3 = conflict_vals
        seg4 = 100 - semantic_vals - conflict_vals

        segment1_data.append(seg1)
        segment2_data.append(seg2)
        segment3_data.append(seg3)
        segment4_data.append(seg4)

    # Convert to numpy arrays for easier manipulation
    import numpy as np

    segment1_data = np.array(segment1_data).T  # Transpose to get models x languages
    segment2_data = np.array(segment2_data).T
    segment3_data = np.array(segment3_data).T
    segment4_data = np.array(segment4_data).T

    # Create x positions for bars
    x = np.arange(n_languages)
    width = 0.8 / n_models  # Width of each bar

    # Define consistent colors for each segment type
    segment_colors = [
        "#2E8B57",
        "#90EE90",
        "#DC143C",
        "#808080",
    ]  # Dark green, Light green, Red, Gray

    # Define patterns for each model
    model_patterns = {
        "Claude opus-4": "",  # Solid fill
        "DeepSeek deepseek-r1-0528": "///",  # Diagonal lines
        "Gemini 2.5-pro": "...",  # Dots
        "Openai/O3 Pro": "---",  # Horizontal lines
        "Qwen qwen3-235B-a22B": "|||",  # Vertical lines
        "X.AI grok-4": "+++",  # Cross-hatch
    }

    # Plot stacked bars for each model
    for i, model in enumerate(models):
        offset = (i - n_models / 2 + 0.5) * width

        # Get pattern for this model
        pattern = model_patterns.get(model, "")

        # Stack the segments with consistent colors and model-specific patterns
        ax.bar(
            x + offset,
            segment1_data[i],
            width,
            color=segment_colors[0],
            alpha=0.9,
            edgecolor="black",
            linewidth=0.5,
            hatch=pattern,
        )

        ax.bar(
            x + offset,
            segment2_data[i],
            width,
            bottom=segment1_data[i],
            color=segment_colors[1],
            alpha=0.9,
            edgecolor="black",
            linewidth=0.5,
            hatch=pattern,
        )

        ax.bar(
            x + offset,
            segment3_data[i],
            width,
            bottom=segment1_data[i] + segment2_data[i],
            color=segment_colors[2],
            alpha=0.9,
            edgecolor="black",
            linewidth=0.5,
            hatch=pattern,
        )

        ax.bar(
            x + offset,
            segment4_data[i],
            width,
            bottom=segment1_data[i] + segment2_data[i] + segment3_data[i],
            color=segment_colors[3],
            alpha=0.9,
            edgecolor="black",
            linewidth=0.5,
            hatch=pattern,
        )

    # Customize the plot
    ax.set_ylabel("Percentage (%)", fontsize=14)
    ax.set_title(
        "Model Performance - Stacked Segments Analysis", fontsize=16, fontweight="bold"
    )
    ax.set_xticks(x)
    ax.set_xticklabels(languages, rotation=45, ha="right")
    ax.set_ylim(0, 100)
    ax.grid(True, alpha=0.3, axis="y")

    # Create custom legend with both model patterns and segment colors
    from matplotlib.patches import Patch

    # Model pattern legend
    model_legend = []
    for model in models:
        pattern = model_patterns.get(model, "")
        model_legend.append(
            Patch(facecolor="lightgray", edgecolor="black", hatch=pattern, label=model)
        )

    # Segment color legend
    segment_labels = [
        "Equivalent to developer",
        "Code normalized equivalent to developer",
        "Conflicts",
        "Different from code normalized to developer",
    ]

    segment_legend = []
    for i, (color, label) in enumerate(zip(segment_colors, segment_labels)):
        patch = Patch(facecolor=color, edgecolor="black", label=label)
        segment_legend.append(patch)

    # Create two separate legends
    legend1 = ax.legend(
        handles=model_legend,
        loc="upper left",
        bbox_to_anchor=(1.02, 1),
        title="Models",
        frameon=True,
    )
    ax.add_artist(legend1)

    ax.legend(
        handles=segment_legend,
        loc="upper left",
        bbox_to_anchor=(1.02, 0.6),
        title="Segments",
        frameon=True,
    )

    # Adjust layout
    plt.tight_layout()

    # Save the plot
    output_file = output_dir / "performance_stacked_bar_chart.pdf"
    plt.savefig(output_file, bbox_inches="tight")
    plt.close()
    print(f"Saved stacked bar chart: {output_file}")


def create_summary_table(df: pd.DataFrame, output_dir: Path) -> None:
    """Create a summary table with averages across all languages, highlighting best values."""

    # Extract unique languages from column names
    languages = []
    for col in df.columns:
        if col.endswith("_Correct"):
            lang = col.replace("_Correct", "")
            languages.append(lang)

    # Calculate averages for each model
    summary_data = []
    for _, row in df.iterrows():
        model = row["Model"]

        # Calculate averages across all languages
        correct_values = [row[f"{lang}_Correct"] for lang in languages]
        semantic_values = [row[f"{lang}_Semantic"] for lang in languages]
        conflict_values = [row[f"{lang}_Conflict"] for lang in languages]

        avg_correct = sum(correct_values) / len(correct_values)
        avg_semantic = sum(semantic_values) / len(semantic_values)
        avg_conflict = sum(conflict_values) / len(conflict_values)

        summary_data.append(
            {
                "Model": model,
                "Avg_Correct": avg_correct,
                "Avg_Semantic": avg_semantic,
                "Avg_Conflict": avg_conflict,
            }
        )

    # Create summary DataFrame
    summary_df = pd.DataFrame(summary_data)

    # Find best values
    best_correct = summary_df["Avg_Correct"].max()
    best_semantic = summary_df["Avg_Semantic"].max()

    # Create markdown table with bold formatting for best values
    markdown_lines = []
    markdown_lines.append("# Model Performance Summary (Averaged Across All Languages)")
    markdown_lines.append("")
    markdown_lines.append(
        "| Model | Avg Correct Merges (%) | Avg Semantic Merges (%) | Avg Conflict Detection (%) |"
    )
    markdown_lines.append(
        "|-------|------------------------|-------------------------|----------------------------|"
    )

    for _, row in summary_df.iterrows():
        model = row["Model"]
        correct = row["Avg_Correct"]
        semantic = row["Avg_Semantic"]
        conflict = row["Avg_Conflict"]

        # Format with bold for best values
        correct_str = (
            f"**{correct:.2f}%**" if correct == best_correct else f"{correct:.2f}%"
        )
        semantic_str = (
            f"**{semantic:.2f}%**" if semantic == best_semantic else f"{semantic:.2f}%"
        )
        conflict_str = f"{conflict:.2f}%"

        markdown_lines.append(
            f"| {model} | {correct_str} | {semantic_str} | {conflict_str} |"
        )

    # Save markdown table
    output_file = output_dir / "performance_summary_table.md"
    with open(output_file, "w", encoding="utf-8") as f:
        f.write("\n".join(markdown_lines))

    print(f"Saved summary table: {output_file}")

    # Create LaTeX table
    latex_lines = []
    latex_lines.append("\\begin{table}[htbp]")
    latex_lines.append("\\centering")
    latex_lines.append(
        "\\caption{Model Performance Summary (Averaged Across All Languages)}"
    )
    latex_lines.append("\\label{tab:model_performance_summary}")
    latex_lines.append("\\begin{tabular}{|l|c|c|c|}")
    latex_lines.append("\\hline")
    latex_lines.append(
        "\\textbf{Model} & \\textbf{Avg Correct Merges (\\%)} & \\textbf{Avg "
        "Normalized Correct Merges (\\%)} & \\textbf{Avg Conflict Detection (\\%)} \\\\"
    )
    latex_lines.append("\\hline")

    for _, row in summary_df.iterrows():
        model = (
            row["Model"].replace("_", "\\_").replace("&", "\\&")
        )  # Escape LaTeX special chars
        correct = row["Avg_Correct"]
        semantic = row["Avg_Semantic"]
        conflict = row["Avg_Conflict"]

        # Format with bold for best values
        correct_str = (
            f"\\textbf{{{correct:.2f}\\%}}"
            if correct == best_correct
            else f"{correct:.2f}\\%"
        )
        semantic_str = (
            f"\\textbf{{{semantic:.2f}\\%}}"
            if semantic == best_semantic
            else f"{semantic:.2f}\\%"
        )
        conflict_str = f"{conflict:.2f}\\%"

        latex_lines.append(
            f"{model} & {correct_str} & {semantic_str} & {conflict_str} \\\\"
        )

    latex_lines.append("\\hline")
    latex_lines.append("\\end{tabular}")
    latex_lines.append("\\end{table}")

    # Save LaTeX table
    latex_output_file = output_dir / "performance_summary_table.tex"
    with open(latex_output_file, "w", encoding="utf-8") as f:
        f.write("\n".join(latex_lines))

    print(f"Saved LaTeX summary table: {latex_output_file}")

    # Also print to console for immediate viewing
    print("\n" + "\n".join(markdown_lines))


def main() -> None:
    """Main function to parse arguments and generate the stacked bar chart."""
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

    # Generate single stacked bar chart visualization
    print("\nGenerating stacked bar chart...")
    create_stacked_bar_chart(df, output_dir)

    # Generate summary table
    print("\nGenerating summary table...")
    create_summary_table(df, output_dir)

    print(f"\nFiles saved to: {output_dir}")


if __name__ == "__main__":
    main()
