"""JSON repair utilities for handling LLM output edge cases."""

import json
import re
from typing import Any


def repair_json(raw_text: str) -> Any:
    """
    Fix common JSON issues from LLM output.

    Args:
        raw_text: Raw text that may contain JSON with issues

    Returns:
        Parsed JSON object

    Raises:
        json.JSONDecodeError: If JSON cannot be repaired and parsed
    """
    text = raw_text.strip()

    # Remove markdown code blocks
    text = re.sub(r'^```json?\s*\n?', '', text)
    text = re.sub(r'\n?```\s*$', '', text)

    # Try parsing as-is first
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    # Fix trailing commas before } or ]
    text = re.sub(r',(\s*[}\]])', r'\1', text)

    # Fix missing quotes around keys (simple cases)
    text = re.sub(r'(\{|\,)\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*:', r'\1"\2":', text)

    # Try parsing again
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    # Try to extract JSON array or object from text
    # Look for first [ or { and last ] or }
    array_match = re.search(r'\[[\s\S]*\]', text)
    if array_match:
        try:
            return json.loads(array_match.group())
        except json.JSONDecodeError:
            pass

    object_match = re.search(r'\{[\s\S]*\}', text)
    if object_match:
        try:
            return json.loads(object_match.group())
        except json.JSONDecodeError:
            pass

    # Last resort: raise the original error
    return json.loads(raw_text)


def validate_word_entry(entry: dict) -> list[str]:
    """
    Validate a single word entry against the expected schema.

    Args:
        entry: Word entry dictionary

    Returns:
        List of validation issues (empty if valid)
    """
    issues = []
    word = entry.get('word', '<unknown>')

    # Required fields
    if not entry.get('word'):
        issues.append(f"Missing 'word' field")
    if not entry.get('phonetic'):
        issues.append(f"Missing 'phonetic' for: {word}")

    # Examples validation
    examples = entry.get('examples', [])
    if not examples:
        issues.append(f"No examples for: {word}")
    elif len(examples) < 2:
        issues.append(f"Less than 2 examples for: {word} (has {len(examples)})")

    for i, ex in enumerate(examples):
        if not ex.get('sentence'):
            issues.append(f"Example {i+1} missing 'sentence' for: {word}")
        if not ex.get('translation_cn'):
            issues.append(f"Example {i+1} missing 'translation_cn' for: {word}")

    return issues
