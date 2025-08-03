# Merge-Bench

![CI](https://github.com/benedikt-schesch/Merge-Bench/actions/workflows/ci.yml/badge.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Python Version](https://img.shields.io/badge/python-3.12%2B-blue.svg)

A benchmarking toolkit for evaluating Large Language Models (LLMs) on merge conflict resolution in code. 🤖

## Evaluation Results 🚀


### All languages

| Model | Equivalent to developer | Code normalized equivalent to developer | Conflicts | Different from code normalized to developer | Invalid Markdown |
|-------|-------------------------|----------------------------------------|-----------|---------------------------------------------|------------------|
| Gemini 2.5 Pro | **47.1%** | **52.6%** | 5.3% | 42.1% | 0.0% |
| o3 Pro | 39.2% | <u>45.1%</u> | 14.1% | 40.9% | 0.0% |
| Claude Opus 4 | <u>40.3%</u> | 44.8% | 20.4% | 34.5% | 0.3% |
| Grok 4 | 27.7% | 31.7% | 47.3% | 20.9% | 0.1% |
| Qwen3 235B | 25.8% | 30.6% | 37.3% | 32.0% | 0.1% |
| R1-0528 671B | 32.0% | 36.5% | 36.9% | 26.3% | 0.4% |

### Java

| Model | Equivalent to developer | Code normalized equivalent to developer | Conflicts | Different from code normalized to developer | Invalid Markdown |
| --- | ---: | ---: | ---: | ---: | ---: |
| Gemini 2.5 Pro | **54.7%** | **62.5%** | 3.4% | 34.1% | 0.0% |
| o3 Pro | 46.1% | 54.3% | 10.6% | 35.1% | 0.0% |
| Claude Opus 4 | 44.4% | 51.2% | 21.2% | 27.6% | 0.0% |
| Grok 4 | 33.4% | 39.7% | 42.4% | 17.9% | 0.0% |
| Llama 4 Maverick | 26.2% | 32.6% | 40.1% | 27.1% | 0.2% |
| QwQ 32B | 32.1% | 43.2% | 20.5% | 30.9% | 5.5% |
| Qwen3 8B | 5.5% | 9.1% | 86.1% | 4.7% | 0.1% |
| Qwen3 14B | 12.9% | 16.6% | 74.7% | 8.7% | 0.0% |
| Qwen3 32B | 13.2% | 16.9% | 71.8% | 11.1% | 0.1% |
| Qwen3 235B | 30.9% | 39.5% | 35.1% | 25.4% | 0.0% |
| R1 1.5B | 0.0% | 0.2% | 44.0% | 46.5% | 9.3% |
| R1 8B | 3.5% | 8.1% | 58.4% | 31.6% | 1.9% |
| R1 14B | 9.3% | 13.4% | 70.7% | 15.4% | 0.5% |
| R1 32B | 22.8% | 30.4% | 39.7% | 29.3% | 0.6% |
| R1 70B | 25.7% | 33.0% | 39.6% | 26.9% | 0.5% |
| R1-0528 671B | 35.9% | 42.4% | 33.2% | 24.0% | 0.4% |
| LLMergeJ 14B | <u>48.8%</u> | <u>58.9%</u> | 5.6% | 35.5% | 0.0% |

## Table of Contents

- [Features ✨](#features)
- [Prerequisites 📋](#prerequisites)
- [Installation ⚙️](#installation)
- [Usage](#usage)
- [Evaluation Metrics 📊](#evaluation-metrics)
- [API Configuration](#api-configuration)
- [Caching](#caching)
- [Project Structure](#project-structure)
- [License](#license)

## Features ✨

- 📊 Evaluate LLMs on merge conflict resolution tasks across 11 programming languages
- 🤖 Support for both local models (via Unsloth) and API-based models (OpenAI, Anthropic, DeepSeek, etc.)
- ⚡ Efficient caching mechanism for API responses
- 📈 Comprehensive evaluation metrics with language-aware code validation
- 🔄 Parallel evaluation support for faster processing
- 🏭 Factory pattern for easy model integration

## Prerequisites 📋

- [uv](https://docs.astral.sh/uv/) - Python package manager

## Installation ⚙️

1. Clone the repository:

   ```bash
   git clone https://github.com/benedikt-schesch/Merge-Bench.git
   cd Merge-Bench
   ```

2. Install dependencies:

   ```bash
   uv sync
   ```

> **Tip:** If you encounter CUDA issues with local models, try:
> ```bash
> uv pip install -U transformers
> ```

## Usage

### Dataset Preparation

This repository focuses on evaluation. To build datasets, use the companion repository [Merge-Bench-Builder](https://github.com/benedikt-schesch/Merge-Bench-Builder).

Datasets are organized by language in the following structure:
```
merges/
├── repos_github_javascript/dataset/
├── repos_reaper_java_test/dataset/
├── repos_github_rust/dataset/
├── repos_reaper_c/dataset/
├── repos_reaper_cpp/dataset/
├── repos_reaper_csharp/dataset/
├── repos_reaper_php/dataset/
├── repos_reaper_python/dataset/
├── repos_reaper_ruby/dataset/
├── repos_github_go/dataset/
└── repos_github_typescript/dataset/
```

### Supported Languages

The evaluation framework supports the following programming languages:
- `javascript` - JavaScript
- `java` - Java
- `rust` - Rust
- `c` - C
- `cpp` - C++
- `csharp` - C#
- `php` - PHP
- `python` - Python
- `ruby` - Ruby
- `go` - Go
- `typescript` - TypeScript

### Running Evaluation

#### Single Model Evaluation

```bash
# Evaluate a model on a specific language
python eval.py --model_name "unsloth/DeepSeek-R1-Distill-Qwen-14B" --language java

# With verbose output
python eval.py --model_name "api/deepseek-r1" --language python --verbose

# Limit samples for testing and have multiple parallel workers
python eval.py --model_name "google/gemini-2.5-pro" --language javascript --max_samples 10 --max_workers 32
```

#### Batch Evaluation Scripts

```bash
# Evaluate all models on all languages
./eval_all_models.sh

# Evaluate Java-specific models
./eval_java_models.sh

# Evaluate SFT (Supervised Fine-Tuned) models on Java
./eval_sft_models.sh
```

### Building Performance Tables

The evaluation scripts automatically generate performance tables in both LaTeX and Markdown formats:

- LaTeX tables: `tables/results_table.tex`, `tables/java_results_table.tex`, `tables/sft_results_table.tex`
- Markdown tables: `tables/results_table.md`, `tables/java_results_table.md`, `tables/sft_results_table.md`
- Summary tables: `tables/performance_summary_table.md`, `tables/performance_summary_table.tex`

## Evaluation Metrics 📊

The evaluation framework measures five key metrics:

1. **Equivalent to developer**: Percentage of conflicts resolved exactly matching the ground truth
2. **Code normalized equivalent to developer**: Percentage of conflicts resolved semantically correctly (ignoring whitespace/comments)
3. **Raising Conflict**: Percentage where the model preserves the original conflict markers
4. **Valid Markdown Format**: Percentage of responses with properly formatted code blocks (language-specific)
5. **Valid Thinking Format**: Percentage of responses following the expected thinking format (if applicable)

## API Configuration

### Environment Variables

Set the following environment variables for API access:

```bash
export DEEPSEEK_API_KEY="your-deepseek-api-key"
export OPENROUTER_API_KEY="your-openrouter-api-key"
```

## Caching

The evaluation system includes an intelligent caching mechanism:

- API responses are cached in `query_cache/` directory
- Cache is organized by model name
- Each unique prompt generates a hash-based cache key
- Cached responses are automatically reused to save API costs

## Project Structure

```
.
├── eval.py                    # Main evaluation script
├── eval_all_models.sh         # Batch evaluation for all models
├── eval_java_models.sh        # Java-specific model evaluation
├── eval_sft_models.sh         # SFT model evaluation with hyperparameter grid
├── src/
│   ├── api_model.py          # API model interface
│   ├── evaluation_metrics.py  # Evaluation metrics and reward functions
│   ├── model_factory.py      # Factory pattern for model instantiation
│   ├── model_interface.py    # Base model interface
│   ├── plot_performance_table.py  # Performance visualization
│   ├── sft_model.py          # Supervised Fine-Tuned model support
│   ├── unsloth_model.py      # Local model support via Unsloth
│   └── utils.py              # Caching and utility functions
├── tables/                    # Evaluation results (LaTeX and Markdown)
├── query_cache/              # API response cache
├── eval_outputs/             # Detailed evaluation outputs
└── merges/                   # Dataset directory
```

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
