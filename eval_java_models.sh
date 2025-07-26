#!/bin/bash

set -euo pipefail

# Default maximum number of parallel workers for eval.py
MAX_WORKERS=${1:-32}

# Fixed language - Java only
LANGUAGE="java"

# List of models to evaluate specifically for Java
MODELS=(
    "google/gemini-2.5-pro"
    "x-ai/grok-4"
    "anthropic/claude-opus-4"
    "openai/o3-pro"
    "meta-llama/llama-4-maverick"
    "qwen/qwq-32b"
    "qwen/qwen3-8b"
    "qwen/qwen3-14b"
    "qwen/qwen3-32b"
    "qwen/qwen3-235b-a22b"
    "deepseek/deepseek-r1-distill-qwen-1.5b"
    "deepseek/deepseek-r1-distill-llama-8b"
    "deepseek/deepseek-r1-distill-qwen-14b"
    "deepseek/deepseek-r1-distill-qwen-32b"
    "deepseek/deepseek-r1-distill-llama-70b"
    "deepseek/deepseek-r1-0528"
    "outputs/unsloth/DeepSeek-R1-Distill-Qwen-14B/checkpoint-2000"
)

# ─── EVALUATION FUNCTIONS ─────────────────────────────────────────────────────

# Function to evaluate one model on Java
evaluate_model() {
    local model="$1"
    local model_name=$(basename "$model")

    echo "[$model_name] Starting Java evaluation"
    python3 eval.py --model_name "$model" --language "$LANGUAGE" --max_workers "$MAX_WORKERS"
    echo "[$model_name] Completed Java evaluation"
}

# ─── PERFORMANCE TABLE FUNCTIONS ───────────────────────────────────────────────

# Function to format model names for display
format_model_name() {
    local model="$1"
    local display_model="$model"

    case "$model" in
        "deepseek/deepseek-r1-0528")
            display_model="DeepSeek R1 0528"
            ;;
        "google/gemini-2.5-pro")
            display_model="Gemini 2.5 Pro"
            ;;
        "x-ai/grok-4")
            display_model="Grok 4"
            ;;
        "qwen/qwen3-235b-a22b")
            display_model="Qwen3 235B"
            ;;
        "anthropic/claude-opus-4")
            display_model="Claude Opus 4"
            ;;
        "openai/o3-pro")
            display_model="o3 Pro"
            ;;
        "outputs/unsloth/DeepSeek-R1-Distill-Qwen-14B/checkpoint-2000")
            display_model="LLmergeJ"
            ;;
        "qwen/qwq-32b")
            display_model="QwQ 32B"
            ;;
        "meta-llama/llama-4-maverick")
            display_model="Llama 4 Maverick"
            ;;
        "qwen/qwen3-8b")
            display_model="Qwen3 8B"
            ;;
        "qwen/qwen3-14b")
            display_model="Qwen3 14B"
            ;;
        "qwen/qwen3-32b")
            display_model="Qwen3 32B"
            ;;
        "deepseek/deepseek-r1-distill-qwen-1.5b")
            display_model="R1 1.5B"
            ;;
        "deepseek/deepseek-r1-distill-llama-8b")
            display_model="R1 8B"
            ;;
        "deepseek/deepseek-r1-distill-qwen-14b")
            display_model="R1 14B"
            ;;
        "deepseek/deepseek-r1-distill-qwen-32b")
            display_model="R1 32B"
            ;;
        "deepseek/deepseek-r1-distill-llama-70b")
            display_model="R1 70B"
            ;;
        *)
            # Default formatting
            display_model=$(echo "$model" | sed 's/-/ /g; s/\b\(.\)/\u\1/g')
            ;;
    esac

    echo "$display_model"
}

# Function to get metrics for a model
get_metrics() {
    local model="$1"
    local logfile="eval_outputs/${LANGUAGE}/${model}/eval.log"

    if [[ -f "$logfile" ]]; then
        # Extract the last-occurring values for each metric
        awk '
            /Percentage correctly resolved merges:/ { correct = $NF; sub(/%$/,"",correct) }
            /Percentage semantically correctly resolved merges:/ { semantic = $NF; sub(/%$/,"",semantic) }
            /Percentage correctly raising merge conflict:/ { conflict = $NF; sub(/%$/,"",conflict) }
            END {
                if (correct == "") correct = "N/A"
                if (semantic == "") semantic = "N/A"
                if (conflict == "") conflict = "N/A"
                print correct, semantic, conflict
            }
        ' "$logfile"
    else
        echo "N/A N/A N/A"
    fi
}

# Function to build performance tables
build_performance_table() {
    echo "📝 Building Java-specific performance table..."

    # Setup output paths
    local OUTPUT_FILE="tables/java_results_table.tex"
    local MD_OUTPUT_FILE="tables/java_results_table.md"

    mkdir -p "$(dirname "$OUTPUT_FILE")"

    echo "📝 Processing ${#MODELS[@]} models for Java"

    # ─── LaTeX Table Creation ─────────────────────────────────────────────────
    cat << EOF > "$OUTPUT_FILE"
\\begin{table}[ht]
\\centering
\\footnotesize
\\begin{tabular}{lccc}
\\toprule
Model & Correct & Semantic & Conflict \\\\
\\midrule
EOF

    # ─── Markdown Table Creation ───────────────────────────────────────────────
    echo "| Model | Correct | Semantic | Conflict |" > "$MD_OUTPUT_FILE"
    echo "| --- | ---: | ---: | ---: |" >> "$MD_OUTPUT_FILE"

    # ─── Process each model ────────────────────────────────────────────────────
    for model in "${MODELS[@]}"; do
        echo "⚙️ Processing model: $model"

        display_model=$(format_model_name "$model")
        read correct semantic conflict < <(get_metrics "$model")

        # LaTeX row
        if [[ "$correct" == "N/A" ]]; then
            latex_row="$display_model & -- & -- & -- \\\\"
        else
            latex_row="$display_model & ${correct}\\% & ${semantic}\\% & ${conflict}\\% \\\\"
        fi

        # Markdown row
        if [[ "$correct" == "N/A" ]]; then
            md_row="| $display_model | -- | -- | -- |"
        else
            md_row="| $display_model | ${correct}% | ${semantic}% | ${conflict}% |"
        fi

        echo "$latex_row" >> "$OUTPUT_FILE"
        echo "$md_row" >> "$MD_OUTPUT_FILE"
    done

    # Close LaTeX table
    cat << 'EOF' >> "$OUTPUT_FILE"
\bottomrule
\end{tabular}
\caption{Java model performance. Metrics shown are: Correct merges (\%), Semantic merges (\%), and Raising conflict (\%).}
\label{tab:java-results}
\end{table}
EOF

    echo "📊 Performance tables generated:"
    echo "   LaTeX: $OUTPUT_FILE"
    echo "   Markdown: $MD_OUTPUT_FILE"
}

# Function to display summary statistics
display_summary() {
    echo ""
    echo "=== JAVA EVALUATION SUMMARY ==="
    echo "Models evaluated: ${#MODELS[@]}"
    echo "Language: $LANGUAGE"
    echo ""

    # Create a simple summary table
    printf "%-20s %10s %10s %10s\n" "Model" "Correct" "Semantic" "Conflict"
    printf "%-20s %10s %10s %10s\n" "--------------------" "----------" "----------" "----------"

    for model in "${MODELS[@]}"; do
        display_model=$(format_model_name "$model")
        read correct semantic conflict < <(get_metrics "$model")

        if [[ "$correct" == "N/A" ]]; then
            printf "%-20s %10s %10s %10s\n" "$display_model" "--" "--" "--"
        else
            printf "%-20s %10s %10s %10s\n" "$display_model" "${correct}%" "${semantic}%" "${conflict}%"
        fi
    done
    echo ""
}

# ─── MAIN EXECUTION ───────────────────────────────────────────────────────────

echo "🚀 Java Model Evaluation Pipeline"
echo "=================================="
echo "Evaluating ${#MODELS[@]} models on Java"
echo "Using $MAX_WORKERS parallel workers within eval.py"
echo "Language: $LANGUAGE"
echo "Models: ${MODELS[*]}"
echo ""
echo "All models will be evaluated in parallel on Java..."
echo ""

# Start all models in parallel for Java evaluation
pids=()
for model in "${MODELS[@]}"; do
    echo "🔄 Starting $(basename "$model") in background..."
    evaluate_model "$model" &
    pids+=($!)
done

# Wait for all models to complete
echo ""
echo "⏳ Waiting for all ${#MODELS[@]} models to complete Java evaluation..."
for pid in "${pids[@]}"; do
    wait "$pid"
done

echo "✅ All Java evaluations completed."
echo ""

# Generate performance tables and summary
echo "📊 Generating performance analysis..."
build_performance_table
display_summary

echo "🎉 Java evaluation pipeline completed successfully!"
echo ""
echo "📁 Results can be found in:"
echo "   - Individual logs: eval_outputs/java/{model_name}/eval.log"
echo "   - LaTeX table: tables/java_results_table.tex"
echo "   - Markdown table: tables/java_results_table.md"
