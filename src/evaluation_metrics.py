# -*- coding: utf-8 -*-
"""Evaluation metrics for merge conflict resolution benchmark"""

import re
from typing import List, Dict
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


def format_reward(completions: List[List[Dict[str, str]]]) -> List[float]:
    """
    Evaluates if the completion matches the expected thinking format.

    Returns:
        0.5 if the completion has the correct <think>...</think> format
        0.0 otherwise
    """
    rewards = [0.5 if THINKING_RE.match(c[0]["content"]) else 0.0 for c in completions]
    return rewards


def code_markdown_reward(completions: List[List[Dict[str, str]]]) -> List[float]:
    """
    Evaluates if the answer contains a properly formatted Java code block.

    Returns:
        1.0 if the answer contains ```...``` markdown
        0.0 otherwise
    """
    # Match any code block with any language specifier (or none)
    pattern = re.compile(r"```[^\n]*\n(.*?)\n```", re.DOTALL)
    
    rewards = []
    for c in completions:
        answer = extract_answer(c[0]["content"])
        if pattern.search(answer):
            rewards.append(1.0)
        else:
            rewards.append(0.0)
    
    return rewards


def merged_conflict_reward(
    prompts: List[List[Dict[str, str]]],
    completions: List[List[Dict[str, str]]],
    answers: List[str],
) -> List[float]:
    """
    Evaluates the quality of merge conflict resolution.

    Returns:
        1.0 if the resolution exactly matches the ground truth
        0.5 if the resolution is semantically correct (ignoring whitespace/comments)
        0.1 if the model preserves the conflict (returns the original conflicted code)
        0.0 otherwise
    """
    # Extract the conflicted code block from the prompt
    goal_code_block = extract_code_block(prompts[0][-1]["content"])

    rewards = []
    for idx, completion in enumerate(completions):
        # Extract code block from the answer portion
        answer_text = extract_answer(completion[0]["content"])
        code_block = extract_code_block(answer_text)

        if code_block is None:
            rewards.append(0.0)
        elif code_block == answers[idx].strip():
            # Exact match
            rewards.append(1.0)
        elif normalize_code(code_block) == normalize_code(
            answers[idx].strip()
        ):
            # Semantic match (ignoring whitespace/comments)
            rewards.append(0.5)
        elif code_block == goal_code_block:
            # Model preserved the conflict
            rewards.append(0.1)
        else:
            rewards.append(0.0)

    return rewards
