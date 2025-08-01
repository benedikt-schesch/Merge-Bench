# -*- coding: utf-8 -*-
"""SFT model implementation matching LLMerge eval.py logic."""

import os
from typing import Any, Optional
from loguru import logger
from .model_interface import ModelInterface

# Set HF_HOME to avoid re-downloading models
os.environ["HF_HOME"] = "/m-coriander/coriander/scheschb/.cache/"


class SFTModel(ModelInterface):
    """SFT model using exact same logic as LLMerge eval.py"""

    def __init__(self, model_name: str):
        self._model_name = model_name
        self._model: Optional[Any] = None
        self._tokenizer: Optional[Any] = None
        self._text_streamer: Optional[Any] = None
        self._loaded = False

    def _load_model(self) -> None:
        """Load the SFT model using same logic as LLMerge eval.py"""
        if self._loaded:
            return

        try:
            # Import torch here to avoid import errors when not available
            import unsloth  # pylint: disable=import-outside-toplevel
            from unsloth.chat_templates import get_chat_template  # pylint: disable=import-outside-toplevel
            from transformers import TextStreamer  # pylint: disable=import-outside-toplevel

            logger.info(f"Loading SFT model: {self._model_name}")

            # Load model and tokenizer with same parameters as LLMerge
            self._model, self._tokenizer = unsloth.FastLanguageModel.from_pretrained(
                model_name=self._model_name,
                max_seq_length=2048,  # MAX_SEQUENCE_LENGTH from LLMerge
                load_in_4bit=False,  # Default from LLMerge
            )

            # Set up chat template for Qwen3 (same as in LLMerge)
            self._tokenizer = get_chat_template(
                self._tokenizer,
                chat_template="qwen-3",
            )

            # Enable inference mode for 2x faster inference
            unsloth.FastLanguageModel.for_inference(self._model)

            # Set up text streamer
            self._text_streamer = TextStreamer(self._tokenizer, skip_prompt=True)

            logger.info(f"SFT model loaded on device: {self._model.device}")
            self._loaded = True

        except Exception as e:
            logger.error(f"Failed to load SFT model '{self._model_name}': {e}")
            raise RuntimeError(f"SFT model loading failed: {e}") from e

    def inference(self, prompt: str, **kwargs: Any) -> str:
        """Generate response using same logic as LLMerge eval.py"""
        if not self._loaded:
            self._load_model()

        # Check if model and tokenizer are loaded
        if self._model is None or self._tokenizer is None:
            raise RuntimeError("Model not properly loaded")

        try:
            # Import torch here to avoid import errors when not available
            import torch  # pylint: disable=import-outside-toplevel

            # Disable gradients for inference
            torch.set_grad_enabled(False)

            # Create chat format from question (same as LLMerge)
            chat_prompt = [{"role": "user", "content": prompt}]

            # Apply chat template with same parameters as LLMerge
            template_kwargs = {
                "add_generation_prompt": True,
                "tokenize": True,
                "return_tensors": "pt",
                "enable_thinking": False,  # Always disabled for SFT models
            }

            inputs = self._tokenizer.apply_chat_template(
                chat_prompt, **template_kwargs
            ).to(self._model.device)

            # Generate with same parameters as LLMerge
            output_tokens = self._model.generate(
                input_ids=inputs,
                streamer=self._text_streamer,
                max_new_tokens=1024,  # MAX_OUTPUT_LENGTH from LLMerge
                temperature=0.7,
                top_p=0.8,
                top_k=20,
                use_cache=True,
            )

            # Get the full completion
            full_completion = self._tokenizer.decode(
                output_tokens[0], skip_special_tokens=False
            )

            # Extract completion same way as LLMerge
            if "<｜Assistant｜>" in full_completion:
                completion = full_completion.split("<｜Assistant｜>", 1)[1]
            elif "<|im_start|>assistant" in full_completion:
                completion = full_completion.split("<|im_start|>assistant", 1)[1]
            else:
                # If no clear delimiter found, return the full completion
                completion = full_completion

            return str(completion)

        except Exception as e:
            logger.error(f"SFT model inference failed for '{self._model_name}': {e}")
            raise RuntimeError(f"SFT inference failed: {e}") from e

    @classmethod
    def is_sft_model(cls, model_name: str) -> bool:
        """Check if a model name corresponds to an SFT model"""
        sft_patterns = [
            "outputs/unsloth/",
            "direct_sft_",
            "checkpoint-",
            "/unsloth_",
        ]
        return any(pattern in model_name for pattern in sft_patterns)
