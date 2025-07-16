#!/bin/bash

set -e

# Default maximum number of parallel workers for eval.py
MAX_WORKERS=${1:-4}

MAX_SAMPLES=${2:-200}

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
    "java"
)

# List of API models to evaluate
MODELS=(
    "deepseek/deepseek-r1-0528"
    "google/gemini-2.5-pro"
    "x-ai/grok-4"
    "qwen/qwen3-235b-a22b"
    "anthropic/claude-opus-4"
    "openai/o3-pro"
)

echo "Evaluating ${#MODELS[@]} models across ${#LANGUAGES[@]} languages"
echo "Using $MAX_WORKERS parallel workers within eval.py"
echo "Languages: ${LANGUAGES[*]}"
echo "Models: ${MODELS[*]}"

total_jobs=$((${#LANGUAGES[@]} * ${#MODELS[@]}))
current_job=0

for language in "${LANGUAGES[@]}"; do
    echo "Starting parallel evaluations for language: $language"

    # Start all models for this language in parallel
    pids=()
    for model in "${MODELS[@]}"; do
        current_job=$((current_job + 1))
        echo "[$current_job/$total_jobs] Starting $model on $language in background"
        python3 eval.py --model_name "$model" --language "$language" --max_samples "$MAX_SAMPLES" --max_workers "$MAX_WORKERS" &
        pids+=($!)
    done

    # Wait for all models to complete for this language
    echo "Waiting for all ${#MODELS[@]} models to complete for $language..."
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    echo "Completed all models for $language"
done

echo "All evaluations completed."

# Generate consolidated performance table
echo "Generating consolidated performance table..."
./src/scripts/build_performance_table.sh "all"
