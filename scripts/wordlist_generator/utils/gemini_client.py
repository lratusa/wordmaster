"""Gemini API client for generating phonetics and example sentences."""

import json
import os
import time
from typing import Optional

try:
    import google.generativeai as genai
except ImportError:
    genai = None

from .json_repair import repair_json


class GeminiClient:
    """Client for Gemini API with structured output for word data generation."""

    def __init__(self, api_key: Optional[str] = None):
        """
        Initialize Gemini client.

        Args:
            api_key: Gemini API key. If not provided, reads from GEMINI_API_KEY env var.
        """
        if genai is None:
            raise ImportError(
                "google-generativeai package not installed. "
                "Run: pip install google-generativeai"
            )

        self.api_key = api_key or os.environ.get('GEMINI_API_KEY')
        if not self.api_key:
            raise ValueError(
                "Gemini API key not provided. Set GEMINI_API_KEY environment variable "
                "or pass api_key parameter."
            )

        genai.configure(api_key=self.api_key)
        self.model = genai.GenerativeModel('gemini-2.0-flash')

        # Rate limiting
        self.requests_per_minute = 15  # Conservative limit
        self.last_request_time = 0
        self.min_request_interval = 60.0 / self.requests_per_minute

    def _rate_limit(self):
        """Apply rate limiting between requests."""
        elapsed = time.time() - self.last_request_time
        if elapsed < self.min_request_interval:
            time.sleep(self.min_request_interval - elapsed)
        self.last_request_time = time.time()

    def generate_word_data(
        self,
        words: list[str],
        max_retries: int = 3,
        retry_delay: float = 5.0
    ) -> list[dict]:
        """
        Generate phonetics and example sentences for a batch of words.

        Args:
            words: List of English words (recommended batch size: 10-20)
            max_retries: Maximum retry attempts on failure
            retry_delay: Delay between retries in seconds

        Returns:
            List of word data dictionaries with structure:
            {
                "word": str,
                "phonetic": str,  # IPA format
                "examples": [
                    {"sentence": str, "translation_cn": str},
                    {"sentence": str, "translation_cn": str}
                ]
            }
        """
        prompt = self._build_prompt(words)

        for attempt in range(max_retries):
            try:
                self._rate_limit()

                response = self.model.generate_content(
                    prompt,
                    generation_config=genai.GenerationConfig(
                        response_mime_type="application/json",
                        temperature=0.3,  # Lower temperature for more consistent output
                    )
                )

                # Parse response
                result = repair_json(response.text)

                # Validate structure
                if not isinstance(result, list):
                    raise ValueError("Response is not a list")

                # Ensure all words are present
                result_words = {item.get('word', '').lower() for item in result}
                missing = [w for w in words if w.lower() not in result_words]

                if missing:
                    print(f"Warning: Missing words in response: {missing}")

                return result

            except Exception as e:
                print(f"Attempt {attempt + 1}/{max_retries} failed: {e}")
                if attempt < max_retries - 1:
                    time.sleep(retry_delay * (attempt + 1))  # Exponential backoff
                else:
                    raise

        return []

    def _build_prompt(self, words: list[str]) -> str:
        """Build the prompt for word data generation."""
        words_str = ', '.join(words)

        return f'''Generate phonetics and example sentences for these English words: {words_str}

For each word, provide:
1. IPA phonetic transcription (e.g., /əˈbændən/)
2. Two simple, practical example sentences with Chinese translations

Return a JSON array with this exact structure for each word:
[
  {{
    "word": "example",
    "phonetic": "/ɪɡˈzæmpəl/",
    "examples": [
      {{"sentence": "This is an example sentence.", "translation_cn": "这是一个例句。"}},
      {{"sentence": "Can you give me an example?", "translation_cn": "你能给我一个例子吗？"}}
    ]
  }}
]

Requirements:
- Use standard IPA notation for phonetics
- Example sentences should be simple and suitable for English learners
- Chinese translations should be natural and accurate
- Each word MUST have exactly 2 examples
- Return ONLY the JSON array, no other text'''
