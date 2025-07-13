# -*- coding: utf-8 -*-
"""Abstract model interface for universal model handling."""

from abc import ABC, abstractmethod
from typing import Any


class ModelInterface(ABC):  # pylint: disable=too-few-public-methods
    """Abstract interface for all model types"""

    @abstractmethod
    def inference(self, prompt: str, **kwargs: Any) -> str:
        """Generate response for given prompt

        Args:
            prompt: Input prompt text
            **kwargs: Model-specific generation parameters

        Returns:
            Generated response text
        """
