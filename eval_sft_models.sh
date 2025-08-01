#!/bin/bash

set -euo pipefail

# Default maximum number of parallel workers for eval.py
MAX_WORKERS=${1:-8}

# Fixed language - Java only (since SFT models are trained on Java)
LANGUAGE="java"

# Configuration arrays for SFT hyperparameter grid
LR=(1e-4 1e-5 1e-6)
WEIGHT_DECAY=(0 0.01)
SCHEDULER=("cosine" "linear")
EPOCHS=(1 3)

# Function to format learning rate for directory names
format_lr() {
    local lr="$1"
    case "$lr" in
        1e-3) echo "0.001";;
        1e-4) echo "0.0001";;
        5e-6) echo "5e-06";;
        5e-5) echo "5e-05";;
        1e-5) echo "1e-05";;
        1e-6) echo "1e-06";;
        *) echo "$lr";;
    esac
}

# Function to format weight decay for directory names
format_wd() {
    local wd="$1"
    [[ "$wd" == "0" ]] && echo "0.0" || echo "$wd"
}

# Generate list of all SFT model configurations
generate_model_configs() {
    local -a configs=()

    for lr in "${LR[@]}"; do
        for wd in "${WEIGHT_DECAY[@]}"; do
            for sched in "${SCHEDULER[@]}"; do
                for epochs in "${EPOCHS[@]}"; do
                    local lr_fmt=$(format_lr "$lr")
                    local wd_fmt=$(format_wd "$wd")
                    local model_path="outputs/unsloth/Qwen3-14B/direct_sft_lr${lr_fmt}_epochs${epochs}_wd${wd_fmt}_${sched}"
                    local config_name="direct_sft_lr${lr_fmt}_epochs${epochs}_wd${wd_fmt}_${sched}"

                    # Only add if the cached evaluation results exist
                    if [[ -d "eval_outputs/java/outputs/unsloth/Qwen3-14B/$config_name" ]]; then
                        configs+=("$model_path")
                    else
                        echo "⚠️  Cached results not found: eval_outputs/java/outputs/unsloth/Qwen3-14B/$config_name"
                    fi
                done
            done
        done
    done

    printf '%s\n' "${configs[@]}"
}

# ─── EVALUATION FUNCTIONS ─────────────────────────────────────────────────────

# Function to evaluate one SFT model on Java
evaluate_sft_model() {
    local model_path="$1"
    local config_name=$(basename "$model_path")

    echo "[$config_name] Starting Java evaluation"

    # Follow the same pattern as eval_java_models.sh - no --output_dir override
    python3 eval.py \
        --model_name "$model_path" \
        --language "$LANGUAGE" \
        --max_workers "$MAX_WORKERS"

    echo "[$config_name] Completed Java evaluation"
}

# ─── PERFORMANCE TABLE FUNCTIONS ───────────────────────────────────────────────

# Function to format SFT model names for display
format_sft_model_name() {
    local model_path="$1"
    local config_name=$(basename "$model_path")

    # Extract hyperparameters from config name
    # Format: direct_sft_lr{lr}_epochs{epochs}_wd{wd}_{scheduler}
    local lr_val=${config_name#*lr}; lr_val=${lr_val%%_*}
    local epochs_val=${config_name#*epochs}; epochs_val=${epochs_val%%_*}
    local wd_val=${config_name#*wd}; wd_val=${wd_val%%_*}
    local sched_val=${config_name##*_}

    echo "SFT lr=${lr_val} ep=${epochs_val} wd=${wd_val} ${sched_val}"
}

# Function to get metrics for an SFT model
get_sft_metrics() {
    local model_path="$1"
    local logfile="eval_outputs/java/${model_path}/eval.log"

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

# Function to build SFT performance tables
build_sft_performance_table() {
    echo "📝 Building SFT performance table..."

    # Setup output paths
    local OUTPUT_FILE="tables/sft_results_table.tex"
    local MD_OUTPUT_FILE="tables/sft_results_table.md"

    mkdir -p "$(dirname "$OUTPUT_FILE")"

    # Get all model configurations
    local -a model_configs
    model_configs=()
    while IFS= read -r line; do
        model_configs+=("$line")
    done < <(generate_model_configs)

    echo "📝 Processing ${#model_configs[@]} SFT model configurations for Java"

    # ─── First pass: find best and second best scores ─────────────────────────
    local best_correct=0
    local second_correct=0
    local best_semantic=0
    local second_semantic=0

    # Collect all scores first
    declare -a correct_scores
    declare -a semantic_scores

    for model_path in "${model_configs[@]}"; do
        read correct semantic conflict markdown < <(get_sft_metrics "$model_path")
        if [[ "$correct" != "N/A" && "$correct" != "" ]]; then
            local corr=$(printf "%.1f" "$correct")
            local sem=$(printf "%.1f" "$semantic")

            correct_scores+=("$corr")
            semantic_scores+=("$sem")
        fi
    done

    # Sort and find best/second best for correct scores
    if [[ ${#correct_scores[@]} -gt 0 ]]; then
        IFS=$'\n' sorted_correct=($(sort -nr <<<"${correct_scores[*]}"))
        unset IFS
        best_correct=${sorted_correct[0]}
        if [[ ${#sorted_correct[@]} -gt 1 ]]; then
            second_correct=${sorted_correct[1]}
        fi
    fi

    # Sort and find best/second best for semantic scores
    if [[ ${#semantic_scores[@]} -gt 0 ]]; then
        IFS=$'\n' sorted_semantic=($(sort -nr <<<"${semantic_scores[*]}"))
        unset IFS
        best_semantic=${sorted_semantic[0]}
        if [[ ${#sorted_semantic[@]} -gt 1 ]]; then
            second_semantic=${sorted_semantic[1]}
        fi
    fi

    echo "📊 Best SFT scores found - Correct: ${best_correct}% (2nd: ${second_correct}%), Semantic: ${best_semantic}% (2nd: ${second_semantic}%)"

    # ─── LaTeX Table Creation ─────────────────────────────────────────────────
    echo 'Epochs & LR & Weight decay & Scheduler & Equivalent to developer & Code normalized equivalent to developer & Conflicts & Different from code normalized to developer & Invalid Markdown \\' > "$OUTPUT_FILE"

    # ─── Markdown Table Creation ───────────────────────────────────────────────
    echo "| Epochs | LR | Weight decay | Scheduler | Equivalent to developer | Code normalized equivalent to developer | Conflicts | Different from code normalized to developer | Invalid Markdown |" > "$MD_OUTPUT_FILE"
    echo "| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |" >> "$MD_OUTPUT_FILE"

    # ─── Second pass: build table with highlighting ───────────────────────────
    for model_path in "${model_configs[@]}"; do
        local config_name=$(basename "$model_path")
        echo "⚙️ Processing SFT config: $config_name"

        # Extract hyperparameters
        local lr_val=${config_name#*lr}; lr_val=${lr_val%%_*}
        local epochs_val=${config_name#*epochs}; epochs_val=${epochs_val%%_*}
        local wd_val=${config_name#*wd}; wd_val=${wd_val%%_*}
        local sched_val=${config_name##*_}

        read correct semantic conflict markdown < <(get_sft_metrics "$model_path")

        if [[ "$correct" == "N/A" ]]; then
            latex_row="${epochs_val} & ${lr_val} & ${wd_val} & ${sched_val} & -- & -- & -- & -- & -- \\\\"
            md_row="| ${epochs_val} | ${lr_val} | ${wd_val} | ${sched_val} | -- | -- | -- | -- | -- |"
        else
            # Calculate the 5 segments from raw metrics
            local segment1=$(printf "%.1f" "$correct")  # Equivalent to developer
            local segment2=$(printf "%.1f" "$semantic")  # Code normalized equivalent

            # Handle markdown format percentage
            if [[ "$markdown" != "N/A" && "$markdown" != "" ]]; then
                local segment5=$(echo "scale=1; 100 - $markdown" | bc -l)  # Invalid markdown format
            else
                local segment5=0
            fi

            # Calculate different segment: 100% - semantic% - conflicts% - invalid_markdown%
            local segment4=$(echo "scale=1; 100 - $segment2 - $conflict - $segment5" | bc -l)
            local segment3=$(printf "%.1f" "$conflict")  # Conflicts

            # Format segments with proper rounding
            segment1=$(printf "%.1f" "$segment1")
            segment2=$(printf "%.1f" "$segment2")
            segment3=$(printf "%.1f" "$segment3")
            segment4=$(printf "%.1f" "$segment4")
            segment5=$(printf "%.1f" "$segment5")

            # Apply highlighting
            latex_seg1="${segment1}\\%"
            latex_seg2="${segment2}\\%"
            md_seg1="${segment1}%"
            md_seg2="${segment2}%"

            # Highlight segment1 (Equivalent to developer)
            if (( $(echo "$segment1 == $best_correct" | bc -l) )); then
                latex_seg1="\\textbf{${segment1}\\%}"
                md_seg1="**${segment1}%**"
            elif [[ "$second_correct" != "0" ]] && (( $(echo "$segment1 == $second_correct" | bc -l) )); then
                latex_seg1="\\underline{${segment1}\\%}"
                md_seg1="<u>${segment1}%</u>"
            fi

            # Highlight segment2 (Code normalized equivalent to developer)
            if (( $(echo "$segment2 == $best_semantic" | bc -l) )); then
                latex_seg2="\\textbf{${segment2}\\%}"
                md_seg2="**${segment2}%**"
            elif [[ "$second_semantic" != "0" ]] && (( $(echo "$segment2 == $second_semantic" | bc -l) )); then
                latex_seg2="\\underline{${segment2}\\%}"
                md_seg2="<u>${segment2}%</u>"
            fi

            # Apply phantom spacing for single-digit percentages
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

            # Apply phantom spacing for other segments
            latex_seg3="${segment3}\\%"
            latex_seg4="${segment4}\\%"
            latex_seg5="${segment5}\\%"

            if (( $(echo "$segment3 < 10" | bc -l) )); then
                latex_seg3="\\phantom{0}${segment3}\\%"
            fi
            if (( $(echo "$segment4 < 10" | bc -l) )); then
                latex_seg4="\\phantom{0}${segment4}\\%"
            fi
            if (( $(echo "$segment5 < 10" | bc -l) )); then
                latex_seg5="\\phantom{0}${segment5}\\%"
            fi

            latex_row="${epochs_val} & ${lr_val} & ${wd_val} & ${sched_val} & ${latex_seg1} & ${latex_seg2} & ${latex_seg3} & ${latex_seg4} & ${latex_seg5} \\\\"
            md_row="| ${epochs_val} | ${lr_val} | ${wd_val} | ${sched_val} | ${md_seg1} | ${md_seg2} | ${segment3}% | ${segment4}% | ${segment5}% |"
        fi

        echo "$latex_row" >> "$OUTPUT_FILE"
        echo "$md_row" >> "$MD_OUTPUT_FILE"
    done

    echo "📊 SFT performance tables generated:"
    echo "   LaTeX: $OUTPUT_FILE"
    echo "   Markdown: $MD_OUTPUT_FILE"
}

# Function to display SFT summary statistics
display_sft_summary() {
    echo ""
    echo "=== SFT JAVA EVALUATION SUMMARY ==="

    local -a model_configs
    model_configs=()
    while IFS= read -r line; do
        model_configs+=("$line")
    done < <(generate_model_configs)

    echo "SFT configurations evaluated: ${#model_configs[@]}"
    echo "Language: $LANGUAGE"
    echo ""

    # Create a summary table
    printf "%-25s %10s %10s %10s %12s\n" "Configuration" "Correct" "Semantic" "Conflict" "Invalid MD"
    printf "%-25s %10s %10s %10s %12s\n" "-------------------------" "----------" "----------" "----------" "------------"

    for model_path in "${model_configs[@]}"; do
        local config_name=$(basename "$model_path")
        local display_name=$(format_sft_model_name "$model_path")
        read correct semantic conflict markdown < <(get_sft_metrics "$model_path")

        if [[ "$correct" == "N/A" ]]; then
            printf "%-25s %10s %10s %10s %12s\n" "$display_name" "--" "--" "--" "--"
        else
            # Calculate invalid markdown percentage
            if [[ "$markdown" != "N/A" && "$markdown" != "" ]]; then
                invalid_markdown=$(echo "scale=1; 100 - $markdown" | bc -l)
                invalid_markdown_display=$(printf "%.1f" "$invalid_markdown")"%"
            else
                invalid_markdown_display="0.0%"
            fi

            printf "%-25s %10s %10s %10s %12s\n" "$display_name" "${correct}%" "${semantic}%" "${conflict}%" "$invalid_markdown_display"
        fi
    done
    echo ""
}

# ─── MAIN EXECUTION ───────────────────────────────────────────────────────────

echo "🚀 SFT Model Evaluation Pipeline"
echo "================================="

# Generate list of available model configurations
echo "🔍 Scanning for SFT model configurations..."
model_configs_array=()
while IFS= read -r line; do
    model_configs_array+=("$line")
done < <(generate_model_configs)

if [[ ${#model_configs_array[@]} -eq 0 ]]; then
    echo "❌ No SFT model configurations found!"
    echo "Expected models in: checkpoints/unsloth_Qwen3-14B/direct_sft_lr*/final_model"
    exit 1
fi

echo "✅ Found ${#model_configs_array[@]} SFT model configurations"
echo "Using $MAX_WORKERS parallel workers within eval.py"
echo "Language: $LANGUAGE"
echo "Output directory: eval_outputs/java/outputs/unsloth/Qwen3-14B/"
echo ""

# List all configurations
echo "📋 SFT Configurations to evaluate:"
for model_path in "${model_configs_array[@]}"; do
    config_name=$(basename "$model_path")
    echo "   - $config_name"
done
echo ""

echo "🔄 Starting evaluation of all SFT configurations in parallel..."
echo ""

# Start all SFT models in parallel for Java evaluation
pids=()
for model_path in "${model_configs_array[@]}"; do
    config_name=$(basename "$model_path")
    echo "🔄 Starting $config_name in background..."
    evaluate_sft_model "$model_path" &
    pids+=($!)
done

# Wait for all models to complete
echo ""
echo "⏳ Waiting for all ${#model_configs_array[@]} SFT configurations to complete Java evaluation..."
for pid in "${pids[@]}"; do
    wait "$pid"
done

echo "✅ All SFT evaluations completed."
echo ""

# Generate performance tables and summary
echo "📊 Generating SFT performance analysis..."
build_sft_performance_table
display_sft_summary

echo "🎉 SFT evaluation pipeline completed successfully!"
echo ""
echo "📁 Results can be found in:"
echo "   - Individual logs: eval_outputs/java/outputs/unsloth/Qwen3-14B/{config_name}/eval.log"
echo "   - LaTeX table: tables/sft_results_table.tex"
echo "   - Markdown table: tables/sft_results_table.md"
