#!/bin/bash

set -e

# Default maximum number of parallel jobs
MAX_PARALLEL=${1:-4}

# Default dataset path
DATASET_PATH=${2:-"merges/repos_reaper_test/dataset"}

# List of API models to evaluate
MODELS=(
    "api/deepseek-r1"
    "anthropic/claude-3.5-sonnet"
    "openai/gpt-4"
    "openai/gpt-3.5-turbo"
    "meta/llama-3.1-70b-instruct"
    "google/gemini-pro"
    "qwen/qwen-2.5-72b-instruct"
)

echo "Evaluating ${#MODELS[@]} models with maximum of $MAX_PARALLEL parallel jobs"
echo "Dataset: $DATASET_PATH"

running=0

for model in "${MODELS[@]}"; do
    # Wait if we've reached the maximum number of parallel jobs
    if [ $running -ge $MAX_PARALLEL ]; then
        wait -n
        running=$((running - 1))
    fi

    echo "Starting evaluation for $model"
    python3 eval.py --model_name "$model" --dataset_path "$DATASET_PATH" &
    running=$((running + 1))
done

# Wait for all remaining background jobs
echo "Waiting for $running remaining jobs to complete..."
wait
echo "All evaluations completed."

# Generate performance table
echo "Generating performance table..."
./src/scripts/build_performance_table.sh
