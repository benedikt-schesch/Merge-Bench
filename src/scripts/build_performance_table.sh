#!/usr/bin/env bash

set -euo pipefail

# ─── 1. Confirm overwrite if output exists ────────────────────────────────────
OUTPUT_FILE="tables/results_table.tex"
mkdir -p "$(dirname "$OUTPUT_FILE")"
if [[ -f "$OUTPUT_FILE" ]]; then
    read -p "$OUTPUT_FILE already exists. Overwrite? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Aborting."
        exit 1
    fi
fi

# ─── 2. Where to look for logs ────────────────────────────────────────────────
ROOT_DIR="eval_outputs/repos_reaper_test/test"

# ─── 3. Start the LaTeX table ────────────────────────────────────────────────
cat << 'EOF' > "$OUTPUT_FILE"
\begin{table}[ht]
\centering
\begin{tabular}{lrrrr}
\toprule
Model & Correct merges & Semantic merges & Raising conflict & Valid Java markdown \\
\midrule
EOF

echo "📝 Building LaTeX table from eval.log files in $ROOT_DIR"
MD_OUTPUT_FILE="tables/results_table.md"
mkdir -p "$(dirname "$MD_OUTPUT_FILE")"
echo "| Model | Correct merges | Semantic merges | Raising conflict | Valid Java markdown |" > "$MD_OUTPUT_FILE"
echo "| --- | ---: | ---: | ---: | ---: |" >> "$MD_OUTPUT_FILE"

# ─── 4. Process all model directories ─────────────────────────────────────────
if [[ -d "$ROOT_DIR" ]]; then
    for model_dir in "$ROOT_DIR"/*; do
        if [[ -d "$model_dir" ]]; then
            model=$(basename "$model_dir")
            logfile="$model_dir/eval.log"
            if [[ -f "$logfile" ]]; then
                echo "⚙️ Processing $model"
                # extract the last-occurring values for each metric
                read valid raise semantic correct < <(
                    awk '
                        /Percentage with valid Java markdown format:/ { v = $NF; sub(/%$/,"",v) }
                        /Percentage correctly raising merge conflict:/ { r = $NF; sub(/%$/,"",r) }
                        /Percentage semantically correctly resolved merges:/ { s = $NF; sub(/%$/,"",s) }
                        /Percentage correctly resolved merges:/ { c = $NF; sub(/%$/,"",c) }
                        END { print v, r, s, c }
                    ' "$logfile"
                )

                # Format model name for display
                display_model="$model"

                # Special formatting for known models
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

                # print one row
                echo "${display_model} & ${correct}\\% & ${semantic}\\% & ${raise}\\% & ${valid}\\% \\\\" >> "$OUTPUT_FILE"
                echo "✅ Added $model to table"
                echo "| ${display_model} | ${correct}% | ${semantic}% | ${raise}% | ${valid}% |" >> "$MD_OUTPUT_FILE"
            else
                echo "⚠️ No eval.log found for $model"
            fi
        fi
    done
else
    echo "⚠️ Directory $ROOT_DIR does not exist"
fi

echo "📝 Finished processing all eval.log files"

# ─── 5. Close out the table ───────────────────────────────────────────────────
cat << 'EOF' >> "$OUTPUT_FILE"
\bottomrule
\end{tabular}
\caption{Merge-resolution performance across models.}
\end{table}
EOF

# ─── 6. Generate PDF and JPEG versions ───────────────────────────────────────
if command -v pdflatex &> /dev/null && command -v convert &> /dev/null; then
    JPEG_OUTPUT_FILE="$(dirname "$OUTPUT_FILE")/results_table.jpg"
    TEX_WRAPPER="$(dirname "$OUTPUT_FILE")/results_table_wrapper.tex"
    cat << LATEX > "$TEX_WRAPPER"
\documentclass{article}
\usepackage[margin=5mm]{geometry}
\usepackage{booktabs}
\usepackage{pdflscape}
\pagestyle{empty}
\begin{document}
\begin{landscape}
\input{$OUTPUT_FILE}
\end{landscape}
\end{document}
LATEX
    echo "🖨 Generating PDF version of the table"
    pdflatex -output-directory "$(dirname "$OUTPUT_FILE")" "$TEX_WRAPPER" > /dev/null 2>&1
    PDF_FILE="$(dirname "$OUTPUT_FILE")/results_table_wrapper.pdf"

    if [[ -f "$PDF_FILE" ]]; then
        convert -density 300 "$PDF_FILE" -quality 90 "$JPEG_OUTPUT_FILE" 2>/dev/null
        echo "✅ JPG version written to $JPEG_OUTPUT_FILE"

        # Rename to final PDF name
        mv "$PDF_FILE" "$(dirname "$OUTPUT_FILE")/results_table.pdf"
        echo "✅ PDF version written to $(dirname "$OUTPUT_FILE")/results_table.pdf"
    fi

    # Cleanup temporary LaTeX files
    echo "🧹 Cleaning up temporary LaTeX files"
    rm -f "$(dirname "$OUTPUT_FILE")"/*.aux "$(dirname "$OUTPUT_FILE")"/*.log "$(dirname "$OUTPUT_FILE")"/*.out
    rm -f "$TEX_WRAPPER"
else
    echo "⚠️ pdflatex or convert not found, skipping PDF/JPEG generation"
fi

echo "✅ Done! Table written to $OUTPUT_FILE"
echo "✅ Markdown table written to $MD_OUTPUT_FILE"
