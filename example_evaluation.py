#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Example script showing how to evaluate a single model on the Merge-Bench dataset.
"""

import os
import subprocess
import sys

def main() -> None:
    """Main function to demonstrate evaluation of multiple models."""
    # Check if API keys are set
    if not os.environ.get("DEEPSEEK_API_KEY") and not os.environ.get("OPENROUTER_API_KEY"):
        print("Error: No API keys found!")
        print("Please set one of the following environment variables:")
        print("  export DEEPSEEK_API_KEY='your-key-here'")
        print("  export OPENROUTER_API_KEY='your-key-here'")
        sys.exit(1)

    # Example models to evaluate
    models = [
        "api/deepseek-r1",  # DeepSeek R1
        "anthropic/claude-3.5-sonnet",  # Claude 3.5 Sonnet
        "openai/gpt-4",  # GPT-4
    ]

    # Dataset path
    dataset_path = "merges/repos_reaper_test/dataset"

    print(f"Evaluating models on dataset: {dataset_path}")
    print("-" * 60)

    for model in models:
        print(f"\nEvaluating {model}...")

        # Check if this model needs specific API key
        if model == "api/deepseek-r1" and not os.environ.get("DEEPSEEK_API_KEY"):
            print(f"Skipping {model} - DEEPSEEK_API_KEY not set")
            continue
        if model != "api/deepseek-r1" and not os.environ.get("OPENROUTER_API_KEY"):
            print(f"Skipping {model} - OPENROUTER_API_KEY not set")
            continue

        # Run evaluation
        cmd = [
            "python", "eval.py",
            "--model_name", model,
            "--dataset_path", dataset_path,
            "--max_workers", "8"  # Adjust based on your API rate limits
        ]

        try:
            subprocess.run(cmd, check=True)
            print(f"✅ Successfully evaluated {model}")
        except subprocess.CalledProcessError as e:
            print(f"❌ Error evaluating {model}: {e}")

    print("\n" + "-" * 60)
    print("Generating performance table...")

    # Generate performance table
    try:
        subprocess.run(["./src/scripts/build_performance_table.sh"], check=True)
        print("✅ Performance table generated successfully!")
        print("Check tables/results_table.md for results")
    except subprocess.CalledProcessError as e:
        print(f"❌ Error generating performance table: {e}")

if __name__ == "__main__":
    main()
