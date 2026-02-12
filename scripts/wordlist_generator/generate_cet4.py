#!/usr/bin/env python3
"""
CET-4 Word List Generator

This script generates a comprehensive CET-4 word list by:
1. Loading source data from KyleBing/english-vocabulary repository
2. Deduplicating and normalizing entries
3. Adding phonetics and example sentences via Gemini Flash API
4. Outputting to the app's JSON format

Usage:
    # First, clone the source data:
    # git clone https://github.com/KyleBing/english-vocabulary.git D:/temp/english-vocabulary

    # Then run:
    python generate_cet4.py

    # To resume from checkpoint:
    python generate_cet4.py --resume

    # To use only source data (no API calls):
    python generate_cet4.py --no-api
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import Optional

try:
    import jsonlines
except ImportError:
    jsonlines = None

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

# Add utils to path
sys.path.insert(0, str(Path(__file__).parent))
from utils.gemini_client import GeminiClient
from utils.json_repair import validate_word_entry


# Configuration
DEFAULT_SOURCE_PATH = "D:/temp/english-vocabulary/json/3-CET4-顺序.json"
DEFAULT_OUTPUT_PATH = Path(__file__).parent.parent.parent / "assets" / "wordlists" / "english" / "cet4.json"
PROGRESS_FILE = Path(__file__).parent / "cet4_progress.jsonl"
BATCH_SIZE = 15  # Words per API request


def load_source_data(source_path: str) -> list[dict]:
    """
    Load and deduplicate source data from KyleBing repository.

    Args:
        source_path: Path to the CET-4 JSON file

    Returns:
        List of deduplicated word entries
    """
    print(f"Loading source data from: {source_path}")

    with open(source_path, encoding='utf-8') as f:
        raw_data = json.load(f)

    # Deduplicate by word, merging translations
    word_map = {}

    for entry in raw_data:
        word = entry.get('word', '').strip().lower()
        if not word:
            continue

        if word not in word_map:
            word_map[word] = {
                'word': entry.get('word', '').strip(),
                'translations': [],
                'phrases': []
            }

        # Merge translations
        for trans in entry.get('translations', []):
            if trans not in word_map[word]['translations']:
                word_map[word]['translations'].append(trans)

        # Merge phrases
        for phrase in entry.get('phrases', []):
            if phrase not in word_map[word]['phrases']:
                word_map[word]['phrases'].append(phrase)

    print(f"Loaded {len(word_map)} unique words (from {len(raw_data)} entries)")
    return list(word_map.values())


def normalize_part_of_speech(translations: list[dict]) -> str:
    """
    Normalize part of speech from translations.

    Args:
        translations: List of translation dictionaries with 'type' field

    Returns:
        Normalized part of speech string
    """
    pos_map = {
        'n': 'n.',
        'v': 'v.',
        'vt': 'vt.',
        'vi': 'vi.',
        'adj': 'adj.',
        'adv': 'adv.',
        'prep': 'prep.',
        'conj': 'conj.',
        'pron': 'pron.',
        'int': 'int.',
        'art': 'art.',
        'num': 'num.',
    }

    types = set()
    for trans in translations:
        pos = trans.get('type', '').lower().strip()
        # Handle compound types like "n & v"
        for part in pos.replace('&', ' ').split():
            part = part.strip()
            if part in pos_map:
                types.add(pos_map[part])
            elif part:
                types.add(part + '.' if not part.endswith('.') else part)

    if not types:
        return ''

    # Sort by common order
    order = ['n.', 'v.', 'vt.', 'vi.', 'adj.', 'adv.', 'prep.', 'conj.', 'pron.']
    sorted_types = sorted(types, key=lambda x: order.index(x) if x in order else 100)

    return '/'.join(sorted_types)


def combine_translations(translations: list[dict]) -> str:
    """
    Combine multiple translations into a single string.

    Args:
        translations: List of translation dictionaries

    Returns:
        Combined translation string
    """
    trans_texts = []
    for trans in translations:
        text = trans.get('translation', '').strip()
        if text and text not in trans_texts:
            trans_texts.append(text)

    return '；'.join(trans_texts)


def load_progress() -> dict[str, dict]:
    """
    Load progress from checkpoint file.

    Returns:
        Dictionary mapping word to generated data
    """
    if not PROGRESS_FILE.exists():
        return {}

    if jsonlines is None:
        print("Warning: jsonlines not installed, cannot load progress")
        return {}

    progress = {}
    with jsonlines.open(PROGRESS_FILE) as reader:
        for item in reader:
            word = item.get('word', '').lower()
            if word:
                progress[word] = item

    print(f"Loaded {len(progress)} words from checkpoint")
    return progress


def save_progress(items: list[dict]):
    """
    Append items to progress file.

    Args:
        items: List of word data dictionaries to save
    """
    if jsonlines is None:
        print("Warning: jsonlines not installed, cannot save progress")
        return

    with jsonlines.open(PROGRESS_FILE, mode='a') as writer:
        for item in items:
            writer.write(item)


def chunks(lst: list, n: int):
    """Yield successive n-sized chunks from lst."""
    for i in range(0, len(lst), n):
        yield lst[i:i + n]


def assign_difficulty(word: str, pos: str) -> int:
    """
    Assign difficulty level based on word characteristics.

    Args:
        word: The English word
        pos: Part of speech

    Returns:
        Difficulty level 1-3
    """
    # Simple heuristic based on word length and common patterns
    word_lower = word.lower()

    # Level 1: Common, short words
    if len(word) <= 5:
        return 1

    # Level 3: Complex words (long, Latin/Greek roots)
    if len(word) >= 10:
        return 3

    # Check for complex suffixes
    complex_suffixes = ['tion', 'sion', 'ment', 'ness', 'ical', 'ious', 'eous']
    for suffix in complex_suffixes:
        if word_lower.endswith(suffix):
            return 3

    # Default to level 2
    return 2


def generate_wordlist(
    source_path: str = DEFAULT_SOURCE_PATH,
    output_path: Optional[Path] = None,
    use_api: bool = True,
    resume: bool = True,
    dry_run: bool = False
) -> dict:
    """
    Generate the CET-4 word list.

    Args:
        source_path: Path to KyleBing source JSON
        output_path: Path for output JSON file
        use_api: Whether to use Gemini API for examples
        resume: Whether to resume from checkpoint
        dry_run: If True, only process 10 words for testing

    Returns:
        Statistics dictionary
    """
    if output_path is None:
        output_path = DEFAULT_OUTPUT_PATH

    # Load source data
    source_data = load_source_data(source_path)

    if dry_run:
        print("DRY RUN: Processing only 10 words")
        source_data = source_data[:10]

    # Load existing progress
    progress = load_progress() if resume else {}

    # Prepare words that need API generation
    words_needing_api = []
    for entry in source_data:
        word_lower = entry['word'].lower()
        if word_lower not in progress:
            words_needing_api.append(entry['word'])

    print(f"Words needing API generation: {len(words_needing_api)}")

    # Generate with API if needed
    if use_api and words_needing_api:
        try:
            client = GeminiClient()
        except (ImportError, ValueError) as e:
            print(f"Warning: Cannot initialize Gemini client: {e}")
            print("Proceeding without API generation...")
            use_api = False

    if use_api and words_needing_api:
        print(f"\nGenerating data for {len(words_needing_api)} words...")
        print(f"Batch size: {BATCH_SIZE}, Estimated batches: {len(words_needing_api) // BATCH_SIZE + 1}")

        for i, batch in enumerate(chunks(words_needing_api, BATCH_SIZE)):
            print(f"\nBatch {i+1}: Processing {len(batch)} words: {batch[:3]}...")

            try:
                results = client.generate_word_data(batch)

                # Validate and save results
                valid_results = []
                for item in results:
                    issues = validate_word_entry(item)
                    if issues:
                        print(f"  Warning: Issues with '{item.get('word', '?')}': {issues[:2]}")
                    valid_results.append(item)

                # Update progress
                for item in valid_results:
                    word_lower = item['word'].lower()
                    progress[word_lower] = item

                # Save checkpoint
                save_progress(valid_results)
                print(f"  Saved {len(valid_results)} words to checkpoint")

            except Exception as e:
                print(f"  Batch failed: {e}")
                print("  Stopping to preserve progress. Run with --resume to continue.")
                break

    # Build final output
    print("\nBuilding final word list...")
    words_output = []

    for entry in source_data:
        word = entry['word']
        word_lower = word.lower()

        # Get API-generated data if available
        api_data = progress.get(word_lower, {})

        # Combine source and API data
        word_entry = {
            'word': word,
            'translation_cn': combine_translations(entry.get('translations', [])),
            'part_of_speech': normalize_part_of_speech(entry.get('translations', [])),
            'phonetic': api_data.get('phonetic', ''),
            'difficulty_level': assign_difficulty(word, entry.get('translations', [])),
            'examples': api_data.get('examples', [])
        }

        # Use phrases from source as fallback examples if no API data
        if not word_entry['examples'] and entry.get('phrases'):
            word_entry['examples'] = [
                {
                    'sentence': phrase.get('phrase', ''),
                    'translation_cn': phrase.get('translation', '')
                }
                for phrase in entry.get('phrases', [])[:2]
                if phrase.get('phrase')
            ]

        words_output.append(word_entry)

    # Sort alphabetically
    words_output.sort(key=lambda x: x['word'].lower())

    # Build final structure
    output = {
        'name': 'CET-4 大学英语四级',
        'language': 'en',
        'description': f'大学英语四级核心词汇 (约{len(words_output)}词)',
        'icon_name': 'school',
        'words': words_output
    }

    # Write output
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print(f"\nOutput written to: {output_path}")

    # Statistics
    stats = {
        'total_words': len(words_output),
        'with_phonetic': sum(1 for w in words_output if w.get('phonetic')),
        'with_examples': sum(1 for w in words_output if len(w.get('examples', [])) >= 2),
        'output_path': str(output_path),
        'file_size_mb': output_path.stat().st_size / (1024 * 1024)
    }

    print(f"\nStatistics:")
    print(f"  Total words: {stats['total_words']}")
    print(f"  With phonetic: {stats['with_phonetic']} ({100*stats['with_phonetic']/stats['total_words']:.1f}%)")
    print(f"  With 2+ examples: {stats['with_examples']} ({100*stats['with_examples']/stats['total_words']:.1f}%)")
    print(f"  File size: {stats['file_size_mb']:.2f} MB")

    return stats


def main():
    parser = argparse.ArgumentParser(description='Generate CET-4 word list')
    parser.add_argument(
        '--source', '-s',
        default=DEFAULT_SOURCE_PATH,
        help='Path to KyleBing source JSON file'
    )
    parser.add_argument(
        '--output', '-o',
        default=str(DEFAULT_OUTPUT_PATH),
        help='Output path for generated word list'
    )
    parser.add_argument(
        '--no-api',
        action='store_true',
        help='Skip API calls, use only source data'
    )
    parser.add_argument(
        '--no-resume',
        action='store_true',
        help='Start fresh, ignoring checkpoint'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Process only 10 words for testing'
    )

    args = parser.parse_args()

    # Check source exists
    if not Path(args.source).exists():
        print(f"Error: Source file not found: {args.source}")
        print("\nTo get the source data, run:")
        print("  git clone https://github.com/KyleBing/english-vocabulary.git D:/temp/english-vocabulary")
        sys.exit(1)

    generate_wordlist(
        source_path=args.source,
        output_path=Path(args.output),
        use_api=not args.no_api,
        resume=not args.no_resume,
        dry_run=args.dry_run
    )


if __name__ == '__main__':
    main()
