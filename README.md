# Merge-Bench

[![CI](https://github.com/benedikt-schesch/Merge-Bench/actions/workflows/ci.yml/badge.svg)]
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Python Version](https://img.shields.io/badge/python-3.12%2B-blue.svg)]

A benchmarking toolkit for evaluating Large Language Models (LLMs) on merge conflict resolution in code. 🤖

## Evaluation Results 🚀

| Model | Correct merges | Semantic merges | Raising conflict | Valid Java markdown |
| --- | ---: | ---: | ---: | ---: |
| GPT 4.1 | 44.04% | 54.09% | 3.23% | 100.00% |
| Claude 3.7 Sonnet | 51.61% | 60.17% | 2.85% | 100.00% |
| Llama 4 Maverick | 26.18% | 32.63% | 31.76% | 99.75% |
| Llama 3.3 70B Instruct | 1.86% | 3.85% | 81.02% | 100.00% |
| Gemini 2.5 Pro Preview | 46.65% | 53.35% | 8.93% | 99.88% |
| Qwen3 235B A22B | 28.16% | 35.73% | 32.75% | 99.13% |
| Grok 3 Beta | 8.81% | 11.66% | 81.27% | 100.00% |
| QwQ 32B | 24.07% | 32.26% | 13.77% | 72.70% |
| o3 | 49.63% | 58.93% | 3.10% | 100.00% |
| Qwen3 14B | 12.90% | 16.63% | 69.48% | 99.88% |
| Qwen3 32B | 13.15% | 16.87% | 61.17% | 99.50% |
| Deepseek R1 Distill Qwen 1.5B | 0.00% | 0.12% | 0.00% | 77.42% |
| Deepseek R1 Distill Llama 8B | 3.35% | 7.57% | 14.76% | 94.17% |
| Deepseek R1 Distill Qwen 14B | 9.31% | 13.40% | 48.88% | 99.38% |
| Deepseek R1 Distill Qwen 32B | 22.83% | 30.40% | 30.65% | 99.01% |
| Deepseek R1 Distill Llama 70B | 25.81% | 33.00% | 29.40% | 98.88% |
| Deepseek R1 | 45.66% | 53.60% | 8.81% | 99.50% |
| Ours | 48.76% | 58.93% | 0.12% | 100.00% |
| Best SFT model |  17.99 % |  23.70 % |  42.56 % |  98.26 % |

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

- 📊 Evaluate LLMs on merge conflict resolution tasks
- 🤖 Support for both local models and API-based models (OpenAI, Anthropic, DeepSeek, etc.)
- ⚡ Efficient caching mechanism for API responses
- 📈 Comprehensive evaluation metrics
- 🔄 Parallel evaluation support for faster processing

## Prerequisites

- Python 3.8 or later
- CUDA-enabled GPU (optional, for local models)
- API keys for cloud-based models (if using)

## Installation ⚙️

1. Clone the repository:

   ```bash
   git clone https://github.com/benedikt-schesch/Merge-Bench.git
   cd Merge-Bench
   ```

2. Create and activate a virtual environment:

   ```bash
   python -m venv .venv
   source .venv/bin/activate
   ```

3. Install dependencies:

   ```bash
   pip install --upgrade pip
   pip install uv
   uv sync
   ```

> **Tip:** If you encounter CUDA issues with local models, try:
> ```bash
> uv pip install -U transformers
> ```

## Usage

### Dataset Preparation

This repository focuses on evaluation. To build datasets, use the companion repository [Merge-Bench-Builder](https://github.com/benedikt-schesch/Merge-Bench-Builder).

Place your prepared dataset in the expected location:
```
merges/repos_reaper_test/dataset/
```

### Running Evaluation

#### Single Model Evaluation

```bash
python eval.py --model_name "unsloth/DeepSeek-R1-Distill-Qwen-14B" --dataset_path "merges/repos_reaper_test/dataset"
```

#### API Model Evaluation

For API-based models, set the appropriate environment variables:

```bash
# For DeepSeek
export DEEPSEEK_API_KEY="your-api-key"
python eval.py --model_name "api/deepseek-r1"

# For OpenRouter models
export OPENROUTER_API_KEY="your-api-key"
python eval.py --model_name "anthropic/claude-3.5-sonnet"
```

#### Parallel Evaluation of Multiple API Models

```bash
./src/scripts/eval_api_models.sh <n_processes> <dataset_path>
```

Example:
```bash
# Evaluate all configured models with 4 parallel workers
./src/scripts/eval_api_models.sh 4

# Evaluate with a custom dataset
./src/scripts/eval_api_models.sh 4 "merges/custom_dataset/dataset"
```

### Building Performance Tables

After evaluation, generate a performance comparison table:

```bash
./src/scripts/build_performance_table.sh
```

Results will be saved to `tables/results_table.tex`.

## Evaluation Metrics 📊

The evaluation framework measures four key metrics:

1. **Correct Merges**: Percentage of conflicts resolved exactly matching the ground truth
2. **Semantic Merges**: Percentage of conflicts resolved semantically correctly (ignoring whitespace/comments)
3. **Raising Conflict**: Percentage where the model preserves the original conflict markers
4. **Valid Java Markdown**: Percentage of responses with properly formatted Java code blocks

## API Configuration

### Supported API Models

- **DeepSeek**: `api/deepseek-r1`
- **OpenAI**: Models starting with `openai/`
- **Anthropic**: Models starting with `anthropic/`
- **Other providers via OpenRouter**: `qwen/`, `meta/`, `google/`, `x-ai/`, `deepseek/`

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
├── src/
│   ├── evaluation_metrics.py  # Evaluation metrics and reward functions
│   ├── utils.py              # Caching and utility functions
│   ├── variables.py          # Configuration variables
│   └── scripts/
│       ├── eval_api_models.sh      # Parallel evaluation of API models
│       └── build_performance_table.sh  # Generate performance tables
├── tables/                    # Evaluation results
├── query_cache/              # API response cache
└── eval_outputs/             # Detailed evaluation outputs
```

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
