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
    # "deepseek/deepseek-r1-0528"
    "google/gemini-2.5-pro"
    "x-ai/grok-4"
    "qwen/qwen3-235b-a22b"
    "anthropic/claude-opus-4"
    "openai/o3-pro"
)

# Function to evaluate one model across all languages
evaluate_model() {
    local model="$1"
    local model_name=$(basename "$model")

    echo "[$model_name] Starting evaluation across all languages"

    for i in "${!LANGUAGES[@]}"; do
        local language="${LANGUAGES[$i]}"
        local progress=$((i + 1))
        local total=${#LANGUAGES[@]}

        echo "[$model_name] [$progress/$total] Evaluating $language"
        python3 eval.py --model_name "$model" --language "$language" --max_samples "$MAX_SAMPLES" --max_workers "$MAX_WORKERS"
    done

    echo "[$model_name] Completed all languages"
}

echo "Evaluating ${#MODELS[@]} models across ${#LANGUAGES[@]} languages"
echo "Using $MAX_WORKERS parallel workers within eval.py"
echo "Languages: ${LANGUAGES[*]}"
echo "Models: ${MODELS[*]}"
echo ""
echo "Each model will progress through all languages at its own speed..."

# Start all models in parallel, each going through all languages
pids=()
for model in "${MODELS[@]}"; do
    echo "Starting $(basename "$model") in background..."
    evaluate_model "$model" &
    pids+=($!)
done

# Wait for all models to complete
echo ""
echo "Waiting for all ${#MODELS[@]} models to complete..."
for pid in "${pids[@]}"; do
    wait "$pid"
done

echo "All evaluations completed."

# Generate consolidated performance table
echo "Generating consolidated performance table..."
./src/scripts/build_performance_table.sh "all"
