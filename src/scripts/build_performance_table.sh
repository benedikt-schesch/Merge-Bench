#!/usr/bin/env bash

set -euo pipefail

# Get language parameter (only "all" supported for matrix table)
LANGUAGE=${1:-"all"}

if [[ "$LANGUAGE" != "all" ]]; then
    echo "Error: Matrix table generation only supports 'all' parameter"
    echo "Usage: $0 all"
    exit 1
fi

# ─── 1. Confirm overwrite if output exists ────────────────────────────────────
OUTPUT_FILE="tables/results_table.tex"
MD_OUTPUT_FILE="tables/results_table.md"

mkdir -p "$(dirname "$OUTPUT_FILE")"

# ─── 2. Define languages and collect all models ───────────────────────────────
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

# Collect all unique models across all languages
declare -A all_models
for lang in "${LANGUAGES[@]}"; do
    lang_dir="eval_outputs/${lang}"
    if [[ -d "$lang_dir" ]]; then
        # Scan for provider directories
        for provider_dir in "$lang_dir"/*; do
            if [[ -d "$provider_dir" ]]; then
                provider=$(basename "$provider_dir")
                # Scan for model directories within each provider
                for model_dir in "$provider_dir"/*; do
                    if [[ -d "$model_dir" ]]; then
                        model=$(basename "$model_dir")
                        # Build full model identifier: provider/model
                        full_model="${provider}/${model}"
                        all_models["$full_model"]=1
                    fi
                done
            fi
        done
    fi
done

# Convert to sorted array
models=($(printf '%s\n' "${!all_models[@]}" | sort))

if [[ ${#models[@]} -eq 0 ]]; then
    echo "No models found in eval_outputs directories"
    exit 1
fi

echo "📝 Found ${#models[@]} models across ${#LANGUAGES[@]} languages"
echo "Models: ${models[*]}"

# ─── 3. Function to format model names ────────────────────────────────────────
format_model_name() {
    local model="$1"
    local display_model="$model"

    case "$model" in
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

    # Capitalize 'b' suffix for billions
    display_model=$(echo "$display_model" | sed -r 's/([0-9]+(\.[0-9]+)?)b/\1B/g')
    echo "$display_model"
}

# ─── 4. Function to get metrics for a model-language combination ───────────────
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

# ─── 5. Start building the LaTeX table ────────────────────────────────────────
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

# ─── 6. Create multi-level headers ────────────────────────────────────────────
# First header row: Model + Language names spanning 3 columns each
header1="Model"
for lang in "${LANGUAGES[@]}"; do
    lang_display=$(echo "${lang^}" | sed 's/Cpp/C++/; s/Csharp/C#/')
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

# ─── 7. Create Markdown table headers ─────────────────────────────────────────
md_header1="| Model"
md_header2="| ---"
md_subheader="| |"
for lang in "${LANGUAGES[@]}"; do
    lang_display=$(echo "${lang^}" | sed 's/Cpp/C++/; s/Csharp/C#/')
    md_header1="${md_header1} | ${lang_display} | | |"
    md_header2="${md_header2} | ---: | ---: | ---: |"
    md_subheader="${md_subheader} Correct | Semantic | Conflict |"
done
md_header1="${md_header1} |"
md_header2="${md_header2} |"

echo "$md_header1" > "$MD_OUTPUT_FILE"
echo "$md_subheader" >> "$MD_OUTPUT_FILE"
echo "$md_header2" >> "$MD_OUTPUT_FILE"

# ─── 8. Process each model ────────────────────────────────────────────────────
for model in "${models[@]}"; do
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
            latex_row="${latex_row} & ${correct}\\% & ${semantic}\\% & ${conflict}\\%"
        fi

        # Add to Markdown row
        if [[ "$correct" == "N/A" ]]; then
            md_row="${md_row} | -- | -- | --"
        else
            md_row="${md_row} | ${correct}% | ${semantic}% | ${conflict}%"
        fi
    done

    # Close rows
    latex_row="${latex_row} \\\\"
    md_row="${md_row} |"

    echo "$latex_row" >> "$OUTPUT_FILE"
    echo "$md_row" >> "$MD_OUTPUT_FILE"
done

# ─── 9. Close out the LaTeX table ─────────────────────────────────────────────
cat << 'EOF' >> "$OUTPUT_FILE"
\bottomrule
\end{tabular}
\caption{Model performance across programming languages. Metrics shown are: Correct merges (\%), Semantic merges (\%), and Raising conflict (\%).}
\end{table}
EOF

echo "📝 Finished processing all models and languages"
