#!/bin/bash

set -euo pipefail

# Function to show help
MAX_WORKERS=${1:-32}

# Fixed language - Java only
LANGUAGE="java"

# List of models to evaluate specifically for Java
MODELS=(
    "google/gemini-2.5-pro"
    "openai/o3-pro"
    "anthropic/claude-opus-4"
    "x-ai/grok-4"
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
            display_model="R1-0528 671B"
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
            display_model="LLMergeJ 14B"
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
            /Percentage with valid markdown format:/ { markdown = $NF; sub(/%$/,"",markdown) }
            END {
                if (correct == "") correct = "N/A"
                if (semantic == "") semantic = "N/A"
                if (conflict == "") conflict = "N/A"
                if (markdown == "") markdown = "N/A"
                print correct, semantic, conflict, markdown
            }
        ' "$logfile"
    else
        echo "N/A N/A N/A N/A"
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

    # ─── First pass: find best and second best scores for segments ─────────────
    local best_segment1=0
    local second_segment1=0
    local best_segment2=0
    local second_segment2=0

    # Collect all scores first
    declare -a segment1_scores
    declare -a segment2_scores

    for model in "${MODELS[@]}"; do
        read correct semantic conflict markdown < <(get_metrics "$model")
        if [[ "$correct" != "N/A" && "$correct" != "" ]]; then
            # Calculate segment1 (correct) and segment2 (semantic - no subtraction)
            local seg1=$(printf "%.1f" "$correct")
            local seg2=$(printf "%.1f" "$semantic")

            segment1_scores+=("$seg1")
            segment2_scores+=("$seg2")
        fi
    done

    # Sort and find best/second best for segment1 scores
    if [[ ${#segment1_scores[@]} -gt 0 ]]; then
        IFS=$'\n' sorted_seg1=($(sort -nr <<<"${segment1_scores[*]}"))
        unset IFS
        best_segment1=${sorted_seg1[0]}
        if [[ ${#sorted_seg1[@]} -gt 1 ]]; then
            second_segment1=${sorted_seg1[1]}
        fi
    fi

    # Sort and find best/second best for segment2 scores
    if [[ ${#segment2_scores[@]} -gt 0 ]]; then
        IFS=$'\n' sorted_seg2=($(sort -nr <<<"${segment2_scores[*]}"))
        unset IFS
        best_segment2=${sorted_seg2[0]}
        if [[ ${#sorted_seg2[@]} -gt 1 ]]; then
            second_segment2=${sorted_seg2[1]}
        fi
    fi

    echo "📊 Best scores found - Segment1: ${best_segment1}% (2nd: ${second_segment1}%), Segment2: ${best_segment2}% (2nd: ${second_segment2}%)"

    # ─── LaTeX Table Creation ─────────────────────────────────────────────────
    echo 'Model & Equivalent to developer & Code normalized equivalent to developer & Conflicts & Different from code normalized to developer & Invalid Markdown \\' > "$OUTPUT_FILE"

    # ─── Markdown Table Creation ───────────────────────────────────────────────
    echo "| Model | Equivalent to developer | Code normalized equivalent to developer | Conflicts | Different from code normalized to developer | Invalid Markdown |" > "$MD_OUTPUT_FILE"
    echo "| --- | ---: | ---: | ---: | ---: | ---: |" >> "$MD_OUTPUT_FILE"

    # ─── Second pass: build table with bolding ────────────────────────────────
    for model in "${MODELS[@]}"; do
        echo "⚙️ Processing model: $model"

        display_model=$(format_model_name "$model")
        read correct semantic conflict markdown < <(get_metrics "$model")

        # Calculate the 5 segments from raw metrics
        if [[ "$correct" == "N/A" ]]; then
            latex_row="$display_model & -- & -- & -- & -- & -- \\\\"
            md_row="| $display_model | -- | -- | -- | -- | -- |"
        else
            # Calculate 5 segments
            local segment1=$(printf "%.1f" "$correct")  # Equivalent to developer
            local segment2=$(printf "%.1f" "$semantic")  # Code normalized equivalent (full semantic)

            # Handle markdown format percentage
            if [[ "$markdown" != "N/A" && "$markdown" != "" ]]; then
                local segment3=$(echo "scale=1; 100 - $markdown" | bc -l)  # Invalid markdown format (100 - valid)
            else
                local segment3=0  # Default to 0 if markdown format not available
            fi

            # Always use consistent equation: Different = 100% - semantic% - conflicts% - invalid_markdown%
            local segment5=$(echo "scale=1; 100 - $segment2 - $conflict - $segment3" | bc -l)

            local segment4=$(printf "%.1f" "$conflict")  # Conflicts

            # Format segments with proper rounding
            segment1=$(printf "%.1f" "$segment1")
            segment2=$(printf "%.1f" "$segment2")
            if [[ "$segment3" != "N/A" ]]; then
                segment3=$(printf "%.1f" "$segment3")
            fi
            segment4=$(printf "%.1f" "$segment4")
            segment5=$(printf "%.1f" "$segment5")

        # Apply highlighting to both segments
        latex_seg1="${segment1}\\%"
        latex_seg2="${segment2}\\%"
        md_seg1="${segment1}%"
        md_seg2="${segment2}%"

        # Highlight segment1 (Equivalent to developer)
        if (( $(echo "$segment1 == $best_segment1" | bc -l) )); then
            latex_seg1="\\textbf{${segment1}\\%}"
            md_seg1="**${segment1}%**"
        elif [[ "$second_segment1" != "0" ]] && (( $(echo "$segment1 == $second_segment1" | bc -l) )); then
            latex_seg1="\\underline{${segment1}\\%}"
            md_seg1="<u>${segment1}%</u>"
        fi

        # Highlight segment2 (Code normalized equivalent to developer)
        if (( $(echo "$segment2 == $best_segment2" | bc -l) )); then
            latex_seg2="\\textbf{${segment2}\\%}"
            md_seg2="**${segment2}%**"
        elif [[ "$second_segment2" != "0" ]] && (( $(echo "$segment2 == $second_segment2" | bc -l) )); then
            latex_seg2="\\underline{${segment2}\\%}"
            md_seg2="<u>${segment2}%</u>"
        fi

        # Apply formatting for segment3 (markdown format)
        if [[ "$segment3" == "N/A" ]]; then
            latex_seg3="--"
            md_seg3="--"
        else
            latex_seg3="${segment3}\\%"
            md_seg3="${segment3}%"
            # Add phantom spacing for single-digit numbers
            if (( $(echo "$segment3 < 10" | bc -l) )); then
                latex_seg3="\\phantom{0}${segment3}\\%"
            fi
        fi

        # Apply phantom spacing for single-digit percentages
        latex_seg4="${segment4}\\%"
        latex_seg5="${segment5}\\%"

        # Add phantom spacing for single-digit numbers
        if (( $(echo "$segment4 < 10" | bc -l) )); then
            latex_seg4="\\phantom{0}${segment4}\\%"
        fi
        if (( $(echo "$segment5 < 10" | bc -l) )); then
            latex_seg5="\\phantom{0}${segment5}\\%"
        fi

        # Also check if segments 1 and 2 need phantom spacing
        if [[ "$latex_seg1" =~ ^[0-9]\.[0-9]\\%$ ]]; then
            latex_seg1="\\phantom{0}${latex_seg1}"
        elif [[ "$latex_seg1" =~ ^\\\\textbf\{[0-9]\.[0-9]\\\\%\}$ ]]; then
            number=$(echo "$latex_seg1" | sed 's/\\textbf{\([0-9.]*\)\\%}/\1/')
            latex_seg1="\\textbf{\\phantom{0}${number}\\%}"
        elif [[ "$latex_seg1" =~ ^\\\\underline\{[0-9]\.[0-9]\\\\%\}$ ]]; then
            number=$(echo "$latex_seg1" | sed 's/\\underline{\([0-9.]*\)\\%}/\1/')
            latex_seg1="\\underline{\\phantom{0}${number}\\%}"
        fi

        if [[ "$latex_seg2" =~ ^[0-9]\.[0-9]\\%$ ]]; then
            latex_seg2="\\phantom{0}${latex_seg2}"
        elif [[ "$latex_seg2" =~ ^\\\\textbf\{[0-9]\.[0-9]\\\\%\}$ ]]; then
            number=$(echo "$latex_seg2" | sed 's/\\textbf{\([0-9.]*\)\\%}/\1/')
            latex_seg2="\\textbf{\\phantom{0}${number}\\%}"
        elif [[ "$latex_seg2" =~ ^\\\\underline\{[0-9]\.[0-9]\\\\%\}$ ]]; then
            number=$(echo "$latex_seg2" | sed 's/\\underline{\([0-9.]*\)\\%}/\1/')
            latex_seg2="\\underline{\\phantom{0}${number}\\%}"
        fi

        latex_row="$display_model & ${latex_seg1} & ${latex_seg2} & ${latex_seg4} & ${latex_seg5} & ${latex_seg3} \\\\"
        if [[ "$segment3" == "N/A" ]]; then
            md_row="| $display_model | ${md_seg1} | ${md_seg2} | ${segment4}% | ${segment5}% | -- |"
        else
            md_row="| $display_model | ${md_seg1} | ${md_seg2} | ${segment4}% | ${segment5}% | ${segment3}% |"
        fi
        fi

        echo "$latex_row" >> "$OUTPUT_FILE"
        echo "$md_row" >> "$MD_OUTPUT_FILE"
    done

    # No table closing - only output the body

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

    # Create a simple summary table with Invalid Markdown column
    printf "%-20s %10s %10s %10s %12s\n" "Model" "Correct" "Semantic" "Conflict" "Invalid MD"
    printf "%-20s %10s %10s %10s %12s\n" "--------------------" "----------" "----------" "----------" "------------"

    for model in "${MODELS[@]}"; do
        display_model=$(format_model_name "$model")
        read correct semantic conflict markdown < <(get_metrics "$model")

        if [[ "$correct" == "N/A" ]]; then
            printf "%-20s %10s %10s %10s %12s\n" "$display_model" "--" "--" "--" "--"
        else
            # Calculate invalid markdown percentage
            if [[ "$markdown" != "N/A" && "$markdown" != "" ]]; then
                invalid_markdown=$(echo "scale=1; 100 - $markdown" | bc -l)
                invalid_markdown_display=$(printf "%.1f" "$invalid_markdown")"%"
            else
                invalid_markdown_display="0.0%"
            fi

            printf "%-20s %10s %10s %10s %12s\n" "$display_model" "${correct}%" "${semantic}%" "${conflict}%" "$invalid_markdown_display"
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
