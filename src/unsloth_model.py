# -*- coding: utf-8 -*-
# pylint: disable=line-too-long
"""UnSloth/Local model implementation."""

from typing import Any
from .model_interface import ModelInterface

MODEL_NAME = "unsloth/DeepSeek-R1-Distill-Qwen-14B"  # Model to use for generation
MAX_OUTPUT_LENGTH = 2048  # Maximum number of tokens of the entire sequence
MAX_PROMPT_LENGTH = 512  # Maximum number of tokens in the prompt
LORA_RANK = 128  # Larger rank = smarter, but slower

SYSTEM_PROMPT = (
    "A conversation between User and Assistant. The user asks a question, and the Assistant solves it. The assistant "
    "first thinks about the reasoning process in the mind and then provides the user with the answer. The reasoning "
    "process is enclosed within <think> </think> followed by the answer, i.e., "
    "<think> reasoning process here </think> answer here"
)

MAX_SEQUENCE_LENGTH = MAX_OUTPUT_LENGTH + MAX_PROMPT_LENGTH + len(SYSTEM_PROMPT)
MAX_SEQUENCE_LENGTH_SFT = 4 * MAX_OUTPUT_LENGTH + MAX_PROMPT_LENGTH + len(SYSTEM_PROMPT)

QUERY_PROMPT = (
    "You are a semantic merge conflict resolution expert. Below is a snippet of code "
    "with surrounding context that includes a merge conflict.\n"
    "Return the entire snippet (including full context) in markdown code syntax as provided, make sure you do not modify the context at all and preserve the spacing as is.\n"
    "Think in terms of intent and semantics that both sides of the merge are trying to achieve.\n"
    "If you are not sure on how to resolve the conflict or if the intent is ambiguous, please return the same snippet with the conflict.\n"
    "Here is the code snippet:\n"
)


class UnSlothModel(ModelInterface):  # pylint: disable=too-few-public-methods
    """Handles local UnSloth/checkpoint models and HuggingFace models"""

    def __init__(self, model_name: str) -> None:
        self._model_name = model_name
        if "sft_" in self._model_name:
            self._system_prompt = False
            self._max_seq_length = MAX_SEQUENCE_LENGTH_SFT
        else:
            self._system_prompt = True
            self._max_seq_length = MAX_SEQUENCE_LENGTH
        self._model = None
        self._tokenizer = None
        self._model = None

    def _load_model(self) -> None:
        """Load model using UnSloth"""
        from unsloth import FastLanguageModel

        self._model, self._tokenizer = FastLanguageModel.from_pretrained(
            model_name=self._model_name,
            max_seq_length=MAX_SEQUENCE_LENGTH,
        )

        # Enable inference mode
        FastLanguageModel.for_inference(self._model)

        # Set pad token if not present
        if self._tokenizer.pad_token is None:
            self._tokenizer.pad_token = self._tokenizer.eos_token

    def inference(self, prompt: str, **kwargs: Any) -> str:
        """Generate response using local model"""
        if self._model is None:
            self._load_model()

        if self._system_prompt:
            chat = [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": prompt},
            ]
        else:
            chat = [
                {"role": "user", "content": prompt},
            ]

        formatted_prompt = self._tokenizer.apply_chat_template(
            chat,
            add_generation_prompt=True,
            tokenize=False,
            return_tensors="pt",
        ).to(self._model.device)  # type: ignore

        # Generate
        inputs = self._tokenizer(formatted_prompt, return_tensors="pt").to(
            self._model.device
        )

        output_tokens = self._model.generate(
            input_ids=inputs,
            max_new_tokens=MAX_OUTPUT_LENGTH,
            use_cache=True,
        )

        # Decode and extract assistant response
        full_completion: str = self._tokenizer.decode(
            output_tokens[0], skip_special_tokens=False
        )

        # Extract only the new generated text (after the prompt)
        if "<｜Assistant｜>" in full_completion:
            completion = full_completion.split("<｜Assistant｜>", 1)[1]
        elif "<|im_start|>assistant" in full_completion:
            completion = full_completion.split("<|im_start|>assistant", 1)[1]
        else:
            raise ValueError("Could not find completion in full output.")

        return completion
