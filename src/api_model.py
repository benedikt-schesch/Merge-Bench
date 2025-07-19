# -*- coding: utf-8 -*-
"""Simplified API-based model implementation using only OpenRouter."""

import time
from typing import Any
from loguru import logger
from .model_interface import ModelInterface
from .utils import cached_query_openrouter


# Define API model prefixes
API_MODEL_PREFIXES = (
    "api/",
    "openai/",
    "anthropic/",
    "qwen/",
    "meta/",
    "google/",
    "x-ai/",
    "deepseek/",
    "o3",
)


class APIModel(ModelInterface):
    """Simplified API model using only OpenRouter"""

    def __init__(self, model_name: str):
        self._model_name = model_name

    def inference(self, prompt: str, **kwargs: Any) -> str:
        """Generate response using OpenRouter with extended retry logic"""

        # First attempt
        try:
            response = cached_query_openrouter(prompt, self._model_name)
            if response is None:
                logger.error(
                    f"OpenRouter API returned None for model {self._model_name}"
                )
                raise ValueError("OpenRouter API returned None")

            result = response["result"]
            reasoning = response.get("reasoning", "No reasoning found")
            completion = f"<think>\n{reasoning}</think>\n{result}"

            # Return clean completion - extraction logic handles API models as-is
            return completion

        except Exception as e:
            logger.warning(
                f"Initial API call failed for model {self._model_name}: {e}."
                " Waiting 1 minute before retries..."
            )

            # Wait 1 minute
            time.sleep(60)

            # Try 5 more times in succession
            for attempt in range(20):
                try:
                    logger.info(
                        f"Retry attempt {attempt + 1}/5 for model {self._model_name}"
                    )
                    response = cached_query_openrouter(prompt, self._model_name)
                    if response is None:
                        logger.error(
                            f"OpenRouter API returned None for model {self._model_name} "
                            f"on retry {attempt + 1}"
                        )
                        raise e

                    result = response["result"]
                    reasoning = response.get("reasoning", "No reasoning found")
                    completion = f"<think>\n{reasoning}</think>\n{result}"

                    logger.info(
                        f"Retry attempt {attempt + 1}/5 succeeded for model {self._model_name}"
                    )
                    # Return clean completion - extraction logic handles API models as-is
                    return completion

                except Exception as retry_error:
                    logger.error(
                        f"Retry attempt {attempt + 1}/5 failed for model {self._model_name}: "
                        f"{retry_error}"
                    )
                    if attempt == 4:  # Last attempt
                        logger.error(
                            f"All retry attempts exhausted for model {self._model_name}"
                        )
                        raise retry_error

            # This shouldn't be reached, but just in case
            raise e

    @classmethod
    def is_api_model(cls, model_name: str) -> bool:
        """Check if a model name corresponds to an API model"""
        return any(model_name.startswith(prefix) for prefix in API_MODEL_PREFIXES)
