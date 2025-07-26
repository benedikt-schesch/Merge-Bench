#!/bin/bash

set -e

# Default maximum number of parallel workers for eval.py
MAX_WORKERS=${1:-32}

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
    "google/gemini-2.5-pro"
    "x-ai/grok-4"
    "anthropic/claude-opus-4"
    "openai/o3-pro"
    "qwen/qwen3-235b-a22b"
    "deepseek/deepseek-r1-0528"
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
        python3 eval.py --model_name "$model" --language "$language" --max_workers "$MAX_WORKERS"
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

# ─── PERFORMANCE TABLE FUNCTIONS ───────────────────────────────────────────────

# Function to format model names for display
format_model_name() {
    local model="$1"
    local display_model="$model"

    case "$model" in
        "deepseek/deepseek-r1-0528")
            display_model="R1 0528"
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
        # Generic patterns for fallback
        "api/deepseek-r1")
            display_model="DeepSeek R1"
            ;;
        "o3")
            display_model="o3"
            ;;
        "openai/gpt-"*)
            rest="${model#openai/gpt-}"
            display_model="GPT ${rest}"
            ;;
        "anthropic/claude-"*)
            rest="${model#anthropic/claude-}"
            display_model="Claude ${rest}"
            ;;
        "meta/llama-"*)
            rest="${model#meta/llama-}"
            display_model="Llama ${rest}"
            ;;
        "google/gemini-"*)
            rest="${model#google/gemini-}"
            display_model="Gemini ${rest}"
            ;;
        "qwen/"*)
            rest="${model#qwen/}"
            display_model="Qwen ${rest}"
            ;;
        "x-ai/"*)
            rest="${model#x-ai/}"
            display_model="X.AI ${rest}"
            ;;
        "deepseek/"*)
            rest="${model#deepseek/}"
            display_model="DeepSeek ${rest}"
            ;;
        *)
            # Default formatting
            display_model=$(echo "$model" | sed 's/-/ /g; s/\b\(.\)/\u\1/g')
            ;;
    esac

    echo "$display_model"
}

# Function to get metrics for a model-language combination
get_metrics() {
    local model="$1"
    local lang="$2"
    local logfile="eval_outputs/${lang}/${model}/eval.log"

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
    echo "📝 Building consolidated performance table..."

    # Setup output paths
    local OUTPUT_FILE="tables/results_table.tex"
    local MD_OUTPUT_FILE="tables/results_table.md"

    mkdir -p "$(dirname "$OUTPUT_FILE")"

    echo "📝 Processing ${#MODELS[@]} models across ${#LANGUAGES[@]} languages"

    # ─── LaTeX Table Creation ─────────────────────────────────────────────────
    num_cols=$((${#LANGUAGES[@]} * 3 + 1))  # 3 metrics per language + 1 for model name

    # Create column specification (l for model name, then ccc for each language)
    col_spec="l"
    for lang in "${LANGUAGES[@]}"; do
        col_spec="${col_spec}ccc"
    done

    cat << EOF > "$OUTPUT_FILE"
\\begin{table}[ht]
\\centering
\\footnotesize
\\begin{tabular}{${col_spec}}
\\toprule
EOF

    # Create multi-level headers
    # First header row: Model + Language names spanning 3 columns each
    header1="Model"
    for lang in "${LANGUAGES[@]}"; do
        case "$lang" in
            "c")
                lang_display="C"
                ;;
            "cpp")
                lang_display="C++"
                ;;
            "csharp")
                lang_display="C#"
                ;;
            "go")
                lang_display="Go"
                ;;
            "javascript")
                lang_display="JavaScript"
                ;;
            "php")
                lang_display="PHP"
                ;;
            "python")
                lang_display="Python"
                ;;
            "ruby")
                lang_display="Ruby"
                ;;
            "rust")
                lang_display="Rust"
                ;;
            "typescript")
                lang_display="TypeScript"
                ;;
            "java")
                lang_display="Java"
                ;;
            *)
                # Capitalize first letter as fallback
                lang_display="$(echo "${lang:0:1}" | tr '[:lower:]' '[:upper:]')${lang:1}"
                ;;
        esac
        header1="${header1} & \\multicolumn{3}{c}{${lang_display}}"
    done
    header1="${header1} \\\\"
    echo "$header1" >> "$OUTPUT_FILE"

    # Second header row: empty + metric names for each language
    header2=""
    for lang in "${LANGUAGES[@]}"; do
        header2="${header2} & Correct & Semantic & Conflict"
    done
    header2="${header2} \\\\"
    echo "$header2" >> "$OUTPUT_FILE"

    echo "\\midrule" >> "$OUTPUT_FILE"

    # ─── Markdown Table Creation ───────────────────────────────────────────────
    md_header1="| Model"
    md_header2="| ---"
    md_subheader="| |"
    for lang in "${LANGUAGES[@]}"; do
        case "$lang" in
            "c")
                lang_display="C"
                ;;
            "cpp")
                lang_display="C++"
                ;;
            "csharp")
                lang_display="C#"
                ;;
            "go")
                lang_display="Go"
                ;;
            "javascript")
                lang_display="JavaScript"
                ;;
            "php")
                lang_display="PHP"
                ;;
            "python")
                lang_display="Python"
                ;;
            "ruby")
                lang_display="Ruby"
                ;;
            "rust")
                lang_display="Rust"
                ;;
            "typescript")
                lang_display="TypeScript"
                ;;
            "java")
                lang_display="Java"
                ;;
            *)
                # Capitalize first letter as fallback
                lang_display="$(echo "${lang:0:1}" | tr '[:lower:]' '[:upper:]')${lang:1}"
                ;;
        esac
        md_header1="${md_header1} | ${lang_display} | | |"
        md_header2="${md_header2} | ---: | ---: | ---: |"
        md_subheader="${md_subheader} Correct | Semantic | Conflict |"
    done
    md_header1="${md_header1} |"
    md_header2="${md_header2} |"

    echo "$md_header1" > "$MD_OUTPUT_FILE"
    echo "$md_subheader" >> "$MD_OUTPUT_FILE"
    echo "$md_header2" >> "$MD_OUTPUT_FILE"

    # ─── Process each model ────────────────────────────────────────────────────
    for model in "${MODELS[@]}"; do
        echo "⚙️ Processing model: $model"

        display_model=$(format_model_name "$model")

        # Start LaTeX row
        latex_row="$display_model"
        md_row="| $display_model"

        # Get metrics for each language
        for lang in "${LANGUAGES[@]}"; do
            read correct semantic conflict < <(get_metrics "$model" "$lang")

            # Add to LaTeX row
            if [[ "$correct" == "N/A" ]]; then
                latex_row="${latex_row} & -- & -- & --"
            else
                # Round to 1 decimal place
                correct_rounded=$(printf "%.1f" "$correct")
                semantic_rounded=$(printf "%.1f" "$semantic")
                conflict_rounded=$(printf "%.1f" "$conflict")
                latex_row="${latex_row} & ${correct_rounded}\\% & ${semantic_rounded}\\% & ${conflict_rounded}\\%"
            fi

            # Add to Markdown row
            if [[ "$correct" == "N/A" ]]; then
                md_row="${md_row} | -- | -- | --"
            else
                # Round to 1 decimal place
                correct_rounded=$(printf "%.1f" "$correct")
                semantic_rounded=$(printf "%.1f" "$semantic")
                conflict_rounded=$(printf "%.1f" "$conflict")
                md_row="${md_row} | ${correct_rounded}% | ${semantic_rounded}% | ${conflict_rounded}%"
            fi
        done

        # Close rows
        latex_row="${latex_row} \\\\"
        md_row="${md_row} |"

        echo "$latex_row" >> "$OUTPUT_FILE"
        echo "$md_row" >> "$MD_OUTPUT_FILE"
    done

    # Close out the LaTeX table
    cat << 'EOF' >> "$OUTPUT_FILE"
\bottomrule
\end{tabular}
\caption{Model performance across programming languages. Metrics shown are: Correct merges (\%), Semantic merges (\%), and Raising conflict (\%).}
\end{table}
EOF

    echo "📊 Performance tables generated:"
    echo "   LaTeX: $OUTPUT_FILE"
    echo "   Markdown: $MD_OUTPUT_FILE"
    echo "📝 Finished processing all models and languages"
}

# Function to build summary table with averages
build_summary_table() {
    echo "📊 Building performance summary table..."

    # Setup output paths
    local MD_SUMMARY_FILE="tables/performance_summary_table.md"
    local LATEX_SUMMARY_FILE="tables/performance_summary_table.tex"

    mkdir -p "$(dirname "$MD_SUMMARY_FILE")"

    # Calculate averages for each model
    declare -a model_averages
    best_avg_correct=0
    best_avg_semantic=0

    # First pass: calculate averages and find best values
    for model in "${MODELS[@]}"; do
        display_model=$(format_model_name "$model")

        total_correct=0
        total_semantic=0
        total_conflict=0
        valid_count=0

        # Sum across all languages
        for lang in "${LANGUAGES[@]}"; do
            read correct semantic conflict < <(get_metrics "$model" "$lang")

            if [[ "$correct" != "N/A" && "$correct" != "" ]]; then
                total_correct=$(echo "$total_correct + $correct" | bc -l)
                total_semantic=$(echo "$total_semantic + $semantic" | bc -l)
                total_conflict=$(echo "$total_conflict + $conflict" | bc -l)
                valid_count=$((valid_count + 1))
            fi
        done

        # Calculate averages
        if [[ $valid_count -gt 0 ]]; then
            avg_correct=$(echo "scale=2; $total_correct / $valid_count" | bc -l)
            avg_semantic=$(echo "scale=2; $total_semantic / $valid_count" | bc -l)
            avg_conflict=$(echo "scale=2; $total_conflict / $valid_count" | bc -l)

            # Track best values
            if (( $(echo "$avg_correct > $best_avg_correct" | bc -l) )); then
                best_avg_correct=$avg_correct
            fi
            if (( $(echo "$avg_semantic > $best_avg_semantic" | bc -l) )); then
                best_avg_semantic=$avg_semantic
            fi
        else
            avg_correct="N/A"
            avg_semantic="N/A"
            avg_conflict="N/A"
        fi

        model_averages+=("$model|$display_model|$avg_correct|$avg_semantic|$avg_conflict")
    done

    echo "📊 Best averages found - Correct: ${best_avg_correct}%, Semantic: ${best_avg_semantic}%"

    # Create Markdown summary table
    cat << 'EOF' > "$MD_SUMMARY_FILE"
# Model Performance Summary (Averaged Across All Languages)

| Model | Avg Correct Merges (%) | Avg Semantic Merges (%) | Avg Conflict Detection (%) |
|-------|------------------------|-------------------------|----------------------------|
EOF

    # Create LaTeX summary table
    cat << 'EOF' > "$LATEX_SUMMARY_FILE"
\begin{table}[htbp]
\centering
\caption{Model Performance Summary (Averaged Across All Languages)}
\label{tab:model_performance_summary}
\begin{tabular}{|l|c|c|c|}
\hline
\textbf{Model} & \textbf{Avg Correct Merges (\%)} & \textbf{Avg Normalized Correct Merges (\%)} & \textbf{Avg Conflict Detection (\%)} \\
\hline
EOF

    # Second pass: generate table rows with formatting
    for model_data in "${model_averages[@]}"; do
        IFS='|' read -r model display_model avg_correct avg_semantic avg_conflict <<< "$model_data"

        if [[ "$avg_correct" == "N/A" ]]; then
            # Markdown row
            echo "| $display_model | -- | -- | -- |" >> "$MD_SUMMARY_FILE"

            # LaTeX row
            latex_model=$(echo "$display_model" | sed 's/_/\\_/g; s/&/\\&/g')
            echo "$latex_model & -- & -- & -- \\\\" >> "$LATEX_SUMMARY_FILE"
        else
            # Format values with bold for best performers - using single digit precision
            # Markdown formatting
            if (( $(echo "$avg_correct == $best_avg_correct" | bc -l) )); then
                md_correct="**$(printf "%.1f" "$avg_correct")%**"
            else
                md_correct="$(printf "%.1f" "$avg_correct")%"
            fi

            if (( $(echo "$avg_semantic == $best_avg_semantic" | bc -l) )); then
                md_semantic="**$(printf "%.1f" "$avg_semantic")%**"
            else
                md_semantic="$(printf "%.1f" "$avg_semantic")%"
            fi

            md_conflict="$(printf "%.1f" "$avg_conflict")%"

            # LaTeX formatting
            if (( $(echo "$avg_correct == $best_avg_correct" | bc -l) )); then
                latex_correct="\\textbf{$(printf "%.1f" "$avg_correct")\\%}"
            else
                latex_correct="$(printf "%.1f" "$avg_correct")\\%"
            fi

            if (( $(echo "$avg_semantic == $best_avg_semantic" | bc -l) )); then
                latex_semantic="\\textbf{$(printf "%.1f" "$avg_semantic")\\%}"
            else
                latex_semantic="$(printf "%.1f" "$avg_semantic")\\%"
            fi

            latex_conflict="$(printf "%.1f" "$avg_conflict")\\%"

            # Write rows
            echo "| $display_model | $md_correct | $md_semantic | $md_conflict |" >> "$MD_SUMMARY_FILE"

            latex_model=$(echo "$display_model" | sed 's/_/\\_/g; s/&/\\&/g')
            echo "$latex_model & $latex_correct & $latex_semantic & $latex_conflict \\\\" >> "$LATEX_SUMMARY_FILE"
        fi
    done

    # Close LaTeX table
    cat << 'EOF' >> "$LATEX_SUMMARY_FILE"
\hline
\end{tabular}
\end{table}
EOF

    echo "📊 Summary tables generated:"
    echo "   Markdown: $MD_SUMMARY_FILE"
    echo "   LaTeX: $LATEX_SUMMARY_FILE"

    # Display summary to console
    echo ""
    echo "=== PERFORMANCE SUMMARY ==="
    cat "$MD_SUMMARY_FILE"
    echo ""
}

# Generate consolidated performance table
echo "Generating consolidated performance table..."
build_performance_table

# Generate summary table
echo "Generating performance summary table..."
build_summary_table
