#!/bin/bash

set -e

# Default maximum number of parallel workers for eval.py
MAX_WORKERS=${1:-128}

MAX_SAMPLES=${2:-50}

# List of all available languages from merges/ directory
LANGUAGES=(
    "c"
    "cpp"
    "csharp"
    "go"
    "javascript"
    "php"
    "python"
    "ruby"
    "rust"
    "typescript"
)

# List of API models to evaluate
MODELS=(
    "deepseek/deepseek-r1-0528"
)

echo "Evaluating ${#MODELS[@]} models across ${#LANGUAGES[@]} languages"
echo "Using $MAX_WORKERS parallel workers within eval.py"
echo "Languages: ${LANGUAGES[*]}"
echo "Models: ${MODELS[*]}"

total_jobs=$((${#LANGUAGES[@]} * ${#MODELS[@]}))
current_job=0

for language in "${LANGUAGES[@]}"; do
    echo "Starting evaluations for language: $language"

    for model in "${MODELS[@]}"; do
        current_job=$((current_job + 1))
        echo "[$current_job/$total_jobs] Evaluating $model on $language"
        python3 eval.py --model_name "$model" --language "$language" --max_samples "$MAX_SAMPLES" --max_workers "$MAX_WORKERS" --verbose
    done
done

echo "All evaluations completed."

# Generate consolidated performance table
echo "Generating consolidated performance table..."
./src/scripts/build_performance_table.sh "all"
