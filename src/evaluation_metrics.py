# -*- coding: utf-8 -*-
"""Evaluation metrics for merge conflict resolution benchmark"""

import re
from src.utils import extract_code_block, normalize_code

# Pre-compile regex patterns for performance
THINKING_RE = re.compile(r"^(?:[\s\S]*?)\n</think>\n(?:[\s\S]*)$", re.DOTALL)

# Conflict markers
CONFLICT_MARKERS = ["<<<<<<<", "=======", "|||||||", ">>>>>>>"]


def extract_answer(text: str) -> str:
    """
    Extracts the answer portion from the response (after </think>).
    If there's no </think>, just returns the original text.
    """
    parts = text.split("</think>", 1)
    return parts[-1] if len(parts) > 1 else parts[0]


def format_reward(completion: str) -> float:
    """
    Evaluates if the completion matches the expected thinking format.

    Returns:
        0.5 if the completion has the correct <think>...</think> format
        0.0 otherwise
    """
    return 0.5 if THINKING_RE.match(completion) else 0.0


def code_markdown_reward(completion: str) -> float:
    """
    Evaluates if the answer contains a properly formatted code block for the specified language.

    Args:
        completion: The model's completion
        language: The programming language to match (e.g., "java", "python", "javascript")

    Returns:
        1.0 if the answer contains ```language...``` markdown
        0.0 otherwise
    """
    pattern = re.compile(r"```[^\n]*\n(.*?)\n```", re.DOTALL)

    answer = extract_answer(completion)
    return 1.0 if pattern.search(answer) else 0.0


def has_conflict_markers(code: str) -> bool:
    """
    Check if code contains any Git conflict markers.

    Args:
        code: The code string to check

    Returns:
        True if any conflict markers are found, False otherwise
    """
    return any(marker in code for marker in CONFLICT_MARKERS)


def merged_conflict_reward(  # pylint: disable=unused-argument
    prompt: str, completion: str, answer: str, language: str = "generic"
) -> float:
    """
    Evaluates the quality of merge conflict resolution.

    Args:
        prompt: The prompt containing the merge conflict
        completion: The model's completion
        answer: The ground truth answer
        language: The programming language for proper normalization

    Returns:
        1.0 if the resolution exactly matches the ground truth
        0.5 if the resolution is semantically correct (ignoring whitespace/comments)
        0.1 if the model preserves the conflict (has conflict markers)
        0.0 otherwise
    """
    # Extract code block from the answer portion
    answer_text = extract_answer(completion)
    code_block = extract_code_block(answer_text)

    if code_block is None:
        return 0.0
    if code_block == answer.strip():
        # Exact match
        return 1.0
    if normalize_code(code_block, language) == normalize_code(answer.strip(), language):
        # Semantic match (ignoring whitespace/comments)
        return 0.5
    if has_conflict_markers(code_block):
        # Model preserved/identified the conflict (has conflict markers)
        return 0.1
    return 0.0
