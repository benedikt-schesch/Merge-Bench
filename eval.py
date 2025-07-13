#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Evaluation script for merge conflict resolution benchmark.
Evaluates API-based models on merge conflict resolution tasks across multiple programming languages.
"""

import argparse
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from tqdm import tqdm
from loguru import logger
from datasets import load_from_disk
from src.evaluation_metrics import (
    merged_conflict_reward,
    format_reward,
    code_markdown_reward,
)
from src.utils import cached_query_deepseek_api, cached_query_openrouter

# Define API model names and prefixes
API_MODEL_NAMES = {"api/deepseek-r1", "o3"}
API_MODEL_PREFIXES = (
    "openai",
    "anthropic",
    "qwen",
    "meta",
    "google",
    "x-ai",
    "deepseek",
)

# Language to dataset mapping
LANGUAGE_DATASETS = {
    "javascript": "repos_github_javascript",
    "rust": "repos_github_rust",
    "c": "repos_reaper_c",
    "cpp": "repos_reaper_cpp",
    "csharp": "repos_reaper_csharp",
    "php": "repos_reaper_php",
    "python": "repos_reaper_python",
    "ruby": "repos_reaper_ruby",
    "go": "repos_github_go",
    "typescript": "repos_github_typescript",
}


def is_api_model(model_name: str) -> bool:
    """Check if the model is an API model."""
    return model_name in API_MODEL_NAMES or any(
        model_name.startswith(prefix) for prefix in API_MODEL_PREFIXES
    )


# Clear log file
with open("eval.log", "w", encoding="utf-8"):
    pass
logger.add("eval.log", backtrace=True, diagnose=True)


def model_inference(example: dict, model_name: str, verbose: bool = False) -> str:
    """Perform model inference using API."""
    if verbose:
        logger.info("[VERBOSE] Input prompt:")
        logger.info("-" * 80)
        logger.info(example["question"])
        logger.info("-" * 80)

    if model_name == "api/deepseek-r1":
        response = cached_query_deepseek_api(example["question"])
        if response is None:
            return ""
        reasoning = response["reasoning"]
        result = response["result"]
        # Combine them into a single string that the evaluation expects
        full_completion = f"<think>\n{reasoning}</think>\n{result}"

        if verbose:
            logger.info("[VERBOSE] Model response:")
            logger.info("-" * 80)
            logger.info(full_completion)
            logger.info("-" * 80)

        return full_completion

    # All other models go through OpenRouter
    response = cached_query_openrouter(example["question"], model_name)
    if response is None:
        return ""
    result = response["result"]
    reasoning = response.get("reasoning", "No reasoning found")
    # Combine them into a single string that the evaluation expects
    full_completion = f"<think>\n{reasoning}</think>\n{result}"

    if verbose:
        logger.info("[VERBOSE] Model response:")
        logger.info("-" * 80)
        logger.info(full_completion)
        logger.info("-" * 80)

    return full_completion


def main() -> None:
    """Main function for evaluation script."""
    # pylint: disable=too-many-branches,too-many-statements
    parser = argparse.ArgumentParser(
        description="Evaluation script for merge conflict resolution benchmark."
    )
    parser.add_argument(
        "--model_name",
        type=str,
        required=True,
        help="API model name (e.g., 'api/deepseek-r1', 'anthropic/claude-3.5-sonnet')",
    )
    parser.add_argument(
        "--language",
        type=str,
        required=True,
        choices=list(LANGUAGE_DATASETS.keys()),
        help="Programming language to evaluate",
    )
    parser.add_argument(
        "--output_dir",
        type=str,
        default="eval_outputs",
        help="Directory to store evaluation outputs",
    )
    parser.add_argument(
        "--split",
        type=str,
        default="test",
        choices=["train", "test"],
        help="Dataset split to evaluate (default: test)",
    )
    parser.add_argument(
        "--max_workers",
        type=int,
        default=32,
        help="Maximum number of parallel workers for API calls",
    )
    parser.add_argument(
        "--max_samples",
        type=int,
        default=None,
        help="Maximum number of samples to evaluate (useful for testing)",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose mode to print model inputs and outputs",
    )
    args = parser.parse_args()

    # Validate model name
    if not is_api_model(args.model_name):
        logger.error(
            f"Model '{args.model_name}' is not a supported API model. "
            f"Supported prefixes: {', '.join(API_MODEL_PREFIXES)}"
        )
        return

    # Construct dataset path from language
    dataset_name = LANGUAGE_DATASETS[args.language]
    dataset_path = f"merges/{dataset_name}/dataset"

    # Check if dataset exists
    if not Path(dataset_path).exists():
        logger.error(f"Dataset not found at {dataset_path}")
        logger.error(f"The {args.language} dataset may not have been built yet.")
        return

    # Load the dataset
    try:
        dataset = load_from_disk(dataset_path)[args.split]
    except Exception as e:
        logger.error(f"Failed to load dataset from {dataset_path}: {e}")
        return

    # Limit dataset size if max_samples is specified
    if args.max_samples is not None and args.max_samples < len(dataset):
        dataset = dataset.select(range(args.max_samples))
        logger.info(f"Limited dataset to {args.max_samples} samples")

    logger.info("Starting evaluation...")
    logger.info(f"Model: {args.model_name}")
    logger.info(f"Language: {args.language}")
    logger.info(f"Dataset: {dataset_path}")
    logger.info(f"Split: {args.split}")
    logger.info(f"Loaded {len(dataset)} examples.")

    # Set up output directory
    output_dir = Path(args.output_dir)
    output_dir = output_dir / args.language / args.split / args.model_name
    output_dir.mkdir(parents=True, exist_ok=True)
    logger.add(output_dir / "eval.log", backtrace=True, diagnose=True)

    # Initialize counters
    total = 0
    count_thinking = 0
    count_code_md = 0
    count_conflict_preserved = 0
    count_resolved_perfectly = 0
    count_resolved_semantically = 0

    # Pre-generate completions in parallel
    def generate_completion(item: tuple) -> None:
        idx, example = item
        output_file_path = output_dir / f"example_{idx}.txt"
        if not output_file_path.exists():
            logger.info(f"Processing example {idx}...")
            full = model_inference(example, args.model_name, args.verbose)
            output_file_path.write_text(full, encoding="utf-8")

    # Generate completions in parallel
    with ThreadPoolExecutor(max_workers=args.max_workers) as executor:
        list(
            tqdm(
                executor.map(generate_completion, enumerate(dataset)),
                total=len(dataset),
                desc="Generating completions",
            )
        )

    # Evaluate completions
    pbar = tqdm(dataset, desc="Evaluating")
    for idx, example in enumerate(pbar):
        total += 1

        output_file_path = output_dir / f"example_{idx}.txt"
        if not output_file_path.exists():
            logger.warning(f"Missing output for example {idx}")
            continue

        with open(output_file_path, "r", encoding="utf-8") as f:
            full_completion = f.read()

        # Extract completion
        completion = full_completion

        # Wrap prompt text into the expected structure
        completions = [[{"content": completion}]]
        prompts = [[{"content": example["question"]}]]
        answers = [example["answer"]]

        # Evaluate the thinking format
        if format_reward(completions)[0] > 0:
            count_thinking += 1

        # Evaluate the code markdown formatting
        if code_markdown_reward(completions)[0] > 0:
            count_code_md += 1

        # Evaluate merge conflict resolution
        reward = merged_conflict_reward(prompts, completions, answers)[0]

        if args.verbose:
            logger.info(f"[VERBOSE] Evaluating example {idx}...")
            # Import extract_code_block for verbose mode
            from src.utils import extract_code_block

            extracted_code = extract_code_block(completion)
            logger.info("[VERBOSE] Extracted code block:")
            logger.info("-" * 80)
            if extracted_code:
                logger.info(extracted_code)
            else:
                logger.info("(No code block found)")
            logger.info("-" * 80)
            logger.info("[VERBOSE] Expected answer:")
            logger.info("-" * 80)
            logger.info(example["answer"])
            logger.info("-" * 80)
            logger.info(f"[VERBOSE] Reward: {reward}")
            logger.info("-" * 80)

        # If the model raises a conflict
        if reward == 0.1:
            count_conflict_preserved += 1

        # If the model resolves the conflict semantically
        if reward >= 0.5:
            logger.info(f"Semantically resolved {idx}.")
            count_resolved_semantically += 1

        # If the model resolves the conflict perfectly
        if reward == 1.0:
            logger.info(f"Perfectly resolved {idx}.")
            count_resolved_perfectly += 1

        # Update progress bar with current percentages
        pbar.set_postfix(
            {
                "Correct": f"{100 * count_resolved_perfectly / total:.2f}%",
                "Semantic": f"{100 * count_resolved_semantically / total:.2f}%",
            }
        )

    # Compute final percentages
    pct_thinking = 100 * count_thinking / total if total > 0 else 0
    pct_code_md = 100 * count_code_md / total if total > 0 else 0
    pct_conflict = 100 * count_conflict_preserved / total if total > 0 else 0
    pct_resolved = 100 * count_resolved_perfectly / total if total > 0 else 0
    pct_resolved_semantic = (
        100 * count_resolved_semantically / total if total > 0 else 0
    )

    # Log results
    logger.success("=" * 60)
    logger.success("Evaluation Results:")
    logger.success(f"Model: {args.model_name}")
    logger.success(f"Language: {args.language}")
    logger.success(f"Total merges evaluated: {total}")
    logger.success(f"Percentage with valid thinking format: {pct_thinking:.2f}%")
    logger.success(
        f"Percentage with valid {args.language} markdown format: {pct_code_md:.2f}%"
    )
    logger.success(f"Percentage correctly raising merge conflict: {pct_conflict:.2f}%")
    logger.success(
        f"Percentage semantically correctly resolved merges: {pct_resolved_semantic:.2f}%"
    )
    logger.success(f"Percentage correctly resolved merges: {pct_resolved:.2f}%")
    logger.success("=" * 60)

    # Save results to file
    results_file = output_dir / "results.txt"
    with open(results_file, "w", encoding="utf-8") as f:
        f.write(f"Model: {args.model_name}\n")
        f.write(f"Language: {args.language}\n")
        f.write(f"Dataset: {dataset_path}\n")
        f.write(f"Split: {args.split}\n")
        f.write(f"Total merges evaluated: {total}\n")
        f.write(f"Percentage with valid thinking format: {pct_thinking:.2f}%\n")
        f.write(
            f"Percentage with valid {args.language} markdown format: {pct_code_md:.2f}%\n"
        )
        f.write(f"Percentage correctly raising merge conflict: {pct_conflict:.2f}%\n")
        f.write(
            f"Percentage semantically correctly resolved merges: {pct_resolved_semantic:.2f}%\n"
        )
        f.write(f"Percentage correctly resolved merges: {pct_resolved:.2f}%\n")

    logger.info(f"Results saved to {results_file}")


if __name__ == "__main__":
    main()
