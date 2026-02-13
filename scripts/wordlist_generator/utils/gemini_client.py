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

    def generate_japanese_enrichment(
        self,
        words: list[dict],
        max_retries: int = 3,
        retry_delay: float = 5.0
    ) -> list[dict]:
        """
        Generate Chinese translations and example sentences for Japanese words.

        Args:
            words: List of word dictionaries with keys: word, reading, meaning_en
            max_retries: Maximum retry attempts on failure
            retry_delay: Delay between retries in seconds

        Returns:
            List of enriched word data dictionaries with structure:
            {
                "word": str,
                "translation_cn": str,
                "examples": [
                    {"sentence": str, "translation_cn": str},
                    {"sentence": str, "translation_cn": str}
                ]
            }
        """
        prompt = self._build_japanese_prompt(words)

        for attempt in range(max_retries):
            try:
                self._rate_limit()

                response = self.model.generate_content(
                    prompt,
                    generation_config=genai.GenerationConfig(
                        response_mime_type="application/json",
                        temperature=0.3,
                    )
                )

                result = repair_json(response.text)

                if not isinstance(result, list):
                    raise ValueError("Response is not a list")

                result_words = {item.get('word', '') for item in result}
                input_words = {w['word'] for w in words}
                missing = input_words - result_words

                if missing:
                    print(f"Warning: Missing words in response: {missing}")

                return result

            except Exception as e:
                print(f"Attempt {attempt + 1}/{max_retries} failed: {e}")
                if attempt < max_retries - 1:
                    time.sleep(retry_delay * (attempt + 1))
                else:
                    raise

        return []

    def _build_japanese_prompt(self, words: list[dict]) -> str:
        """Build the prompt for Japanese word enrichment."""
        words_info = []
        for w in words:
            words_info.append(f"- {w['word']} ({w['reading']}): {w['meaning_en']}")
        words_str = '\n'.join(words_info)

        return f'''For each Japanese word below, provide:
1. Chinese translation (translation_cn) - accurate and natural
2. Two example sentences in Japanese with Chinese translations

Japanese words to process:
{words_str}

Return a JSON array with this exact structure:
[
  {{
    "word": "食べる",
    "translation_cn": "吃",
    "examples": [
      {{"sentence": "朝ごはんを食べます。", "translation_cn": "吃早饭。"}},
      {{"sentence": "何を食べたいですか。", "translation_cn": "你想吃什么？"}}
    ]
  }}
]

Requirements:
- Chinese translations should be concise and accurate
- Example sentences should be natural and suitable for Japanese learners
- Use appropriate politeness level (です/ます form preferred for beginners)
- Each word MUST have exactly 2 examples
- Return ONLY the JSON array, no other text'''

    def generate_cefr_word_data(
        self,
        words: list[str],
        cefr_level: str,
        max_retries: int = 3,
        retry_delay: float = 5.0
    ) -> list[dict]:
        """
        Generate Chinese translations, phonetics, and example sentences for CEFR words.

        Args:
            words: List of English words (recommended batch size: 10-20)
            cefr_level: CEFR level (A1, A2, B1, B2, C1, C2)
            max_retries: Maximum retry attempts on failure
            retry_delay: Delay between retries in seconds

        Returns:
            List of word data dictionaries with structure:
            {
                "word": str,
                "translation_cn": str,
                "phonetic": str,  # IPA format
                "examples": [
                    {"sentence": str, "translation_cn": str},
                    {"sentence": str, "translation_cn": str}
                ]
            }
        """
        prompt = self._build_cefr_prompt(words, cefr_level)

        for attempt in range(max_retries):
            try:
                self._rate_limit()

                response = self.model.generate_content(
                    prompt,
                    generation_config=genai.GenerationConfig(
                        response_mime_type="application/json",
                        temperature=0.3,
                    )
                )

                result = repair_json(response.text)

                if not isinstance(result, list):
                    raise ValueError("Response is not a list")

                result_words = {item.get('word', '').lower() for item in result}
                missing = [w for w in words if w.lower() not in result_words]

                if missing:
                    print(f"Warning: Missing words in response: {missing}")

                return result

            except Exception as e:
                print(f"Attempt {attempt + 1}/{max_retries} failed: {e}")
                if attempt < max_retries - 1:
                    time.sleep(retry_delay * (attempt + 1))
                else:
                    raise

        return []

    def _build_cefr_prompt(self, words: list[str], cefr_level: str) -> str:
        """Build the prompt for CEFR word data generation."""
        words_str = ', '.join(words)

        # Adjust complexity based on CEFR level
        level_guidance = {
            'A1': 'very simple sentences suitable for complete beginners',
            'A2': 'simple sentences suitable for elementary learners',
            'B1': 'moderately complex sentences suitable for intermediate learners',
            'B2': 'complex sentences suitable for upper-intermediate learners',
            'C1': 'sophisticated sentences suitable for advanced learners',
            'C2': 'nuanced sentences suitable for proficient speakers',
        }

        complexity = level_guidance.get(cefr_level, 'sentences appropriate for the word level')

        return f'''Generate Chinese translations, IPA phonetics, and example sentences for these {cefr_level} level English words: {words_str}

For each word, provide:
1. Chinese translation (translation_cn) - concise and accurate
2. IPA phonetic transcription (e.g., /əˈbændən/)
3. Two example sentences with Chinese translations - use {complexity}

Return a JSON array with this exact structure for each word:
[
  {{
    "word": "example",
    "translation_cn": "例子；范例",
    "phonetic": "/ɪɡˈzæmpəl/",
    "examples": [
      {{"sentence": "This is an example.", "translation_cn": "这是一个例子。"}},
      {{"sentence": "Can you give me an example?", "translation_cn": "你能给我一个例子吗？"}}
    ]
  }}
]

Requirements:
- Chinese translations should be concise, listing main meanings separated by ；
- Use standard IPA notation for phonetics
- Example sentences should match {cefr_level} difficulty level
- Chinese translations of examples should be natural and accurate
- Each word MUST have exactly 2 examples
- Return ONLY the JSON array, no other text'''
