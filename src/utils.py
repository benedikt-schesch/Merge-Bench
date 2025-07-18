# -*- coding: utf-8 -*-
"""Utility functions for the project."""

from typing import Optional, Dict
import re
import os
import hashlib
import json
from pathlib import Path
import time
from openai import OpenAI
from loguru import logger

# Language to markdown identifier mapping
LANGUAGE_MARKDOWN = {
    "javascript": "javascript",
    "rust": "rust",
    "c": "c",
    "cpp": "cpp",
    "csharp": "csharp",
    "php": "php",
    "python": "python",
    "ruby": "ruby",
    "java": "java",
    "generic": "code",  # fallback for unknown languages
}

# For normalizing code
BLOCK_COMMENT_RE = re.compile(r"/\*[\s\S]*?\*/")
LINE_COMMENT_RE = re.compile(r"//.*")
HASH_COMMENT_RE = re.compile(r"#.*")
WHITESPACE_RE = re.compile(r"\s+")

CONFLICT_MARKERS = ["<<<<<<<", "=======", "|||||||", ">>>>>>>"]


def normalize_code(code: str, language: str = "generic") -> str:
    """
    Normalizes code by removing comments and extra whitespace
    (so we focus on core semantics).
    For whitespace-sensitive languages, whitespace is preserved.
    """
    # Handle different comment styles based on language
    if language in [
        "javascript",
        "java",
        "c",
        "cpp",
        "csharp",
        "rust",
        "php",
        "typescript",
    ]:
        # C-style comments
        code = BLOCK_COMMENT_RE.sub("", code)
        code = LINE_COMMENT_RE.sub("", code)
    elif language in ["python", "ruby"]:
        # Hash comments
        code = HASH_COMMENT_RE.sub("", code)
        # Python/Ruby also have multi-line strings that can act as comments
        # This is a simplified approach
        code = re.sub(r'"""[\s\S]*?"""', "", code)
        code = re.sub(r"'''[\s\S]*?'''", "", code)
    elif language == "go":
        # Go uses C-style comments
        code = BLOCK_COMMENT_RE.sub("", code)
        code = LINE_COMMENT_RE.sub("", code)

    # Skip whitespace normalization for whitespace-sensitive languages
    if language not in ["python", "go", "ruby"]:
        # Remove extra whitespace for non-sensitive languages
        code = WHITESPACE_RE.sub(" ", code)
        return code.strip()

    # For whitespace-sensitive languages, just strip leading/trailing whitespace
    return code.strip()


def extract_code_block(text: str) -> Optional[str]:
    """
    Extracts the code block from a markdown-formatted text.
    Matches any language specifier in the markdown code block.
    Returns None if there's no code block.
    """
    # Match any code block with any language specifier (or none)
    # This pattern matches ```anything or just ```
    pattern = re.compile(r"```[^\n]*\n(.*?)\n```", re.DOTALL)
    match = pattern.search(text)

    if match:
        return match.group(1).strip()

    return None


CACHE_DIR = Path("query_cache")
CACHE_DIR.mkdir(parents=True, exist_ok=True)


def get_cache_key(prompt: str) -> str:
    """Generate a unique cache key for a prompt."""
    return hashlib.md5(prompt.encode()).hexdigest()


def load_from_cache(cache_key: str, model_name: str) -> Optional[Dict[str, str]]:
    """Load response from cache if it exists."""
    cache_file = CACHE_DIR / model_name / f"{cache_key}.json"
    if cache_file.exists():
        with open(cache_file, "r", encoding="utf-8") as f:
            data: Dict[str, str] = json.load(f)
            return data
    return None


def save_to_cache(cache_key: str, response: Dict[str, str], model_name: str) -> None:
    """Save response to cache."""
    (CACHE_DIR / model_name).mkdir(parents=True, exist_ok=True)
    cache_file = CACHE_DIR / model_name / f"{cache_key}.json"
    with open(cache_file, "w", encoding="utf-8") as file:
        json.dump(response, file, indent=4)


def cached_query_openrouter(prompt: str, model: str) -> Optional[Dict[str, str]]:
    """
    Query the specified OpenRouter model with caching.

    :param prompt: the user prompt to send
    :param model: the OpenRouter model name (e.g. "gpt-4o", "claude-2.0")
    :returns: dict with keys "prompt", "result" (and "reasoning" if available)
    """
    # Build a cache key that includes the model name
    cache_key = get_cache_key(prompt)
    # Try load from cache
    cached = load_from_cache(cache_key, model)
    if cached:
        logger.info(f"Using cached response for model={model}")
        return cached

    # Get API credentials / endpoint
    api_key = os.environ.get("OPENROUTER_API_KEY")
    if not api_key:
        logger.error("OPENROUTER_API_KEY environment variable not set")
        raise ValueError("OPENROUTER_API_KEY key not set")
    if model == "o3":
        # O3 has restricted access
        client = OpenAI(api_key=api_key)
    else:
        client = OpenAI(api_key=api_key, base_url="https://openrouter.ai/api/v1")
    # Attempt the call with up to 3 retries
    for attempt in range(3):
        try:
            resp = client.chat.completions.create(
                model=model,
                messages=[{"role": "user", "content": prompt}],
                stream=False,
            )
            print(resp)
            # Extract content; reasoning may or may not be present
            content = resp.choices[0].message.content
            reasoning = getattr(resp.choices[0].message, "reasoning_content", None)

            if content is None:
                raise ValueError("Response is missing content")

            result: Dict[str, str] = {"prompt": prompt, "result": content}
            if reasoning is not None:
                result["reasoning"] = reasoning

            # Cache and return
            save_to_cache(cache_key, result, model)
            return result

        except Exception as e:
            logger.error(f"[OpenRouter] attempt {attempt + 1} failed: {e}")
            if attempt < 2:
                time.sleep(2)
            else:
                raise

    # Shouldn't get here
    raise ValueError("Failed to query OpenRouter API after 3 attempts")
