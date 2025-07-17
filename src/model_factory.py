# -*- coding: utf-8 -*-
"""Model factory for creating appropriate model instances."""

from loguru import logger
from .model_interface import ModelInterface
from .api_model import APIModel
from .unsloth_model import UnSlothModel


class ModelFactory:  # pylint: disable=too-few-public-methods
    """Factory to create appropriate model instances"""

    @staticmethod
    def create_model(model_name: str) -> ModelInterface:
        """Create the appropriate model instance

        Args:
            model_name: Model identifier
            **kwargs: Additional parameters for model initialization

        Returns:
            ModelInterface instance

        Raises:
            ValueError: If model type cannot be determined
            RuntimeError: If model creation fails
        """
        try:
            # Check if it's an API model
            if APIModel.is_api_model(model_name):
                return APIModel(model_name)
            return UnSlothModel(model_name)

        except Exception as e:
            logger.error(f"Failed to create model '{model_name}': {e}")
            raise RuntimeError(f"Model creation failed: {e}") from e
