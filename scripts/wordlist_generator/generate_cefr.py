#!/usr/bin/env python3
"""
CEFR Word List Generator

Generates CEFR vocabulary word lists (A1-C2) from open-source vocabulary data,
enriched with Gemini API for Chinese translations and example sentences.

Data Sources:
- CEFR-J Vocabulary Profile (A1-B2): openlanguageprofiles/olp-en-cefrj
- Octanove Vocabulary Profile (C1-C2): openlanguageprofiles/olp-en-cefrj

Usage:
    python generate_cefr.py --level a1          # Generate A1 word list
    python generate_cefr.py --level all         # Generate all levels
    python generate_cefr.py --level b1 --resume # Resume from checkpoint
    python generate_cefr.py --level a1 --dry-run # Test with 10 words
"""

import argparse
import csv
import json
import os
import sys
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


# Configuration for each CEFR level
CEFR_CONFIGS = {
    'a1': {
        'level': 'A1',
        'output': 'cefr_a1.json',
        'name': 'CEFR A1 入门',
        'description': '欧洲语言共同参考框架 A1 级别词汇',
        'difficulty': 1,
        'progress_file': 'cefr_a1_progress.jsonl',
    },
    'a2': {
        'level': 'A2',
        'output': 'cefr_a2.json',
        'name': 'CEFR A2 初级',
        'description': '欧洲语言共同参考框架 A2 级别词汇',
        'difficulty': 1,
        'progress_file': 'cefr_a2_progress.jsonl',
    },
    'b1': {
        'level': 'B1',
        'output': 'cefr_b1.json',
        'name': 'CEFR B1 中级',
        'description': '欧洲语言共同参考框架 B1 级别词汇',
        'difficulty': 2,
        'progress_file': 'cefr_b1_progress.jsonl',
    },
    'b2': {
        'level': 'B2',
        'output': 'cefr_b2.json',
        'name': 'CEFR B2 中高级',
        'description': '欧洲语言共同参考框架 B2 级别词汇',
        'difficulty': 2,
        'progress_file': 'cefr_b2_progress.jsonl',
    },
    'c1': {
        'level': 'C1',
        'output': 'cefr_c1.json',
        'name': 'CEFR C1 高级',
        'description': '欧洲语言共同参考框架 C1 级别词汇',
        'difficulty': 3,
        'progress_file': 'cefr_c1_progress.jsonl',
    },
    'c2': {
        'level': 'C2',
        'output': 'cefr_c2.json',
        'name': 'CEFR C2 精通',
        'description': '欧洲语言共同参考框架 C2 级别词汇',
        'difficulty': 3,
        'progress_file': 'cefr_c2_progress.jsonl',
    },
}

# File paths
DATA_DIR = Path(__file__).parent / 'data' / 'cefr'
CEFRJ_FILE = DATA_DIR / 'cefrj-vocabulary-profile-1.5.csv'
OCTANOVE_FILE = DATA_DIR / 'octanove-vocabulary-profile-c1c2-1.0.csv'
OUTPUT_DIR = Path(__file__).parent.parent.parent / 'assets' / 'wordlists' / 'english'
CHECKPOINT_DIR = Path(__file__).parent / 'checkpoints'

BATCH_SIZE = 15


def load_cefr_words(level: str) -> list[dict]:
    """
    Load words for a specific CEFR level from source CSV files.

    Returns list of dicts with: word, pos (part of speech)
    """
    level_upper = level.upper()
    words = {}  # word -> {word, pos_list}

    # Determine which file to use
    if level_upper in ['A1', 'A2', 'B1', 'B2']:
        source_file = CEFRJ_FILE
    else:  # C1, C2
        source_file = OCTANOVE_FILE

    if not source_file.exists():
        raise FileNotFoundError(f"Source file not found: {source_file}")

    print(f"Loading {level_upper} words from: {source_file}")

    with open(source_file, encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row['CEFR'] != level_upper:
                continue

            headword = row['headword'].strip()
            pos = row['pos'].strip()

            # Skip empty entries
            if not headword:
                continue

            # Normalize headword (take first variant if multiple)
            # e.g., "a.m./A.M./am/AM" -> "a.m."
            if '/' in headword:
                headword = headword.split('/')[0].strip()

            word_lower = headword.lower()

            if word_lower not in words:
                words[word_lower] = {
                    'word': headword,
                    'pos_list': []
                }

            if pos and pos not in words[word_lower]['pos_list']:
                words[word_lower]['pos_list'].append(pos)

    # Convert to list and sort
    result = []
    for word_data in words.values():
        result.append({
            'word': word_data['word'],
            'part_of_speech': normalize_pos(word_data['pos_list'])
        })

    result.sort(key=lambda x: x['word'].lower())
    print(f"Loaded {len(result)} unique words for {level_upper}")
    return result


def normalize_pos(pos_list: list[str]) -> str:
    """Normalize part of speech list to standard format."""
    pos_map = {
        'noun': 'n.',
        'verb': 'v.',
        'adjective': 'adj.',
        'adverb': 'adv.',
        'preposition': 'prep.',
        'conjunction': 'conj.',
        'pronoun': 'pron.',
        'interjection': 'int.',
        'determiner': 'det.',
        'number': 'num.',
        'modal': 'modal',
        'auxiliary': 'aux.',
        'prefix': 'prefix',
        'suffix': 'suffix',
    }

    normalized = []
    for pos in pos_list:
        pos_lower = pos.lower()
        if pos_lower in pos_map:
            norm = pos_map[pos_lower]
            if norm not in normalized:
                normalized.append(norm)
        elif pos and pos not in normalized:
            # Keep as-is if not in map
            normalized.append(pos)

    # Sort by common order
    order = ['n.', 'v.', 'adj.', 'adv.', 'prep.', 'conj.', 'pron.', 'det.']
    normalized.sort(key=lambda x: order.index(x) if x in order else 100)

    return '/'.join(normalized) if normalized else ''


def load_progress(progress_file: Path) -> dict[str, dict]:
    """Load progress from checkpoint file."""
    if not progress_file.exists():
        return {}
    if jsonlines is None:
        print("Warning: jsonlines not installed, cannot load checkpoint")
        return {}

    progress = {}
    with jsonlines.open(progress_file) as reader:
        for item in reader:
            word = item.get('word', '').lower()
            if word:
                progress[word] = item
    print(f"Loaded {len(progress)} words from checkpoint")
    return progress


def save_progress(progress_file: Path, items: list[dict]):
    """Append items to progress file."""
    if jsonlines is None:
        return

    progress_file.parent.mkdir(parents=True, exist_ok=True)
    with jsonlines.open(progress_file, mode='a') as writer:
        for item in items:
            writer.write(item)


def chunks(lst: list, n: int):
    """Yield successive n-sized chunks from lst."""
    for i in range(0, len(lst), n):
        yield lst[i:i + n]


def generate_cefr_wordlist(
    level: str,
    config: dict,
    use_api: bool = True,
    resume: bool = True,
    dry_run: bool = False,
) -> dict:
    """Generate word list for a specific CEFR level."""
    print(f"\n{'='*60}")
    print(f"Generating CEFR {config['level']} word list")
    print(f"{'='*60}")

    progress_file = CHECKPOINT_DIR / config['progress_file']

    # Load source words
    source_words = load_cefr_words(config['level'])

    if dry_run:
        print("DRY RUN: Processing only 10 words")
        source_words = source_words[:10]

    # Load progress
    progress = load_progress(progress_file) if resume else {}

    # Find words needing API
    words_needing_api = []
    for entry in source_words:
        word_lower = entry['word'].lower()
        if word_lower not in progress:
            words_needing_api.append(entry['word'])

    print(f"Words needing API generation: {len(words_needing_api)}")

    # Generate with API
    if use_api and words_needing_api:
        try:
            client = GeminiClient()
            print(f"\nGenerating data for {len(words_needing_api)} words...")
            print(f"Batch size: {BATCH_SIZE}, Estimated batches: {(len(words_needing_api) + BATCH_SIZE - 1) // BATCH_SIZE}")

            for i, batch in enumerate(chunks(words_needing_api, BATCH_SIZE)):
                batch_num = i + 1
                total_batches = (len(words_needing_api) + BATCH_SIZE - 1) // BATCH_SIZE
                print(f"\nBatch {batch_num}/{total_batches}: Processing {len(batch)} words: {batch[:3]}...")

                try:
                    results = client.generate_cefr_word_data(batch, config['level'])

                    valid_results = []
                    for item in results:
                        issues = validate_word_entry(item)
                        if issues:
                            print(f"  Warning: Issues with '{item.get('word', '?')}': {issues[:2]}")
                        valid_results.append(item)

                    for item in valid_results:
                        progress[item['word'].lower()] = item

                    save_progress(progress_file, valid_results)
                    print(f"  Saved {len(valid_results)} words to checkpoint")

                except Exception as e:
                    print(f"  Batch failed: {e}")
                    print("  Stopping to preserve progress. Run with --resume to continue.")
                    break

        except (ImportError, ValueError) as e:
            print(f"Warning: Cannot initialize Gemini client: {e}")
            print("Proceeding without API generation...")

    # Build final output
    print("\nBuilding final word list...")
    all_words = []

    for entry in source_words:
        word = entry['word']
        word_lower = word.lower()
        api_data = progress.get(word_lower, {})

        word_entry = {
            'word': word,
            'translation_cn': api_data.get('translation_cn', ''),
            'part_of_speech': entry['part_of_speech'] or api_data.get('part_of_speech', ''),
            'phonetic': api_data.get('phonetic', ''),
            'cefr_level': config['level'],
            'difficulty_level': config['difficulty'],
            'examples': api_data.get('examples', [])
        }

        all_words.append(word_entry)

    # Sort alphabetically
    all_words.sort(key=lambda x: x['word'].lower())

    # Write output
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    output_data = {
        'name': config['name'],
        'language': 'en',
        'description': f"{config['description']} ({len(all_words)}词)",
        'icon_name': 'school',
        'words': all_words
    }

    output_path = OUTPUT_DIR / config['output']
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2)

    print(f"Word list written to: {output_path}")

    # Statistics
    stats = {
        'total_words': len(all_words),
        'with_translation': sum(1 for w in all_words if w.get('translation_cn')),
        'with_phonetic': sum(1 for w in all_words if w.get('phonetic')),
        'with_examples': sum(1 for w in all_words if len(w.get('examples', [])) >= 2),
    }

    print(f"\nStatistics for CEFR {config['level']}:")
    print(f"  Total words: {stats['total_words']}")
    print(f"  With translation: {stats['with_translation']} ({100*stats['with_translation']/stats['total_words']:.1f}%)")
    print(f"  With phonetic: {stats['with_phonetic']} ({100*stats['with_phonetic']/stats['total_words']:.1f}%)")
    print(f"  With 2+ examples: {stats['with_examples']} ({100*stats['with_examples']/stats['total_words']:.1f}%)")

    return stats


def main():
    parser = argparse.ArgumentParser(description='Generate CEFR word lists')
    parser.add_argument(
        '--level', '-l',
        choices=list(CEFR_CONFIGS.keys()) + ['all'],
        required=True,
        help='CEFR level to generate (a1-c2 or all)'
    )
    parser.add_argument(
        '--no-api',
        action='store_true',
        help='Skip API calls'
    )
    parser.add_argument(
        '--resume',
        action='store_true',
        help='Resume from checkpoint'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Process only 10 words for testing'
    )

    args = parser.parse_args()

    levels = list(CEFR_CONFIGS.keys()) if args.level == 'all' else [args.level]

    print(f"Will generate CEFR word lists for: {', '.join(levels)}")

    all_stats = {}
    for level in levels:
        config = CEFR_CONFIGS[level]
        stats = generate_cefr_wordlist(
            level=level,
            config=config,
            use_api=not args.no_api,
            resume=args.resume,
            dry_run=args.dry_run,
        )
        all_stats[level] = stats

    print(f"\n{'='*60}")
    print("SUMMARY")
    print(f"{'='*60}")
    for level, stats in all_stats.items():
        if stats:
            print(f"CEFR {level.upper()}: {stats['total_words']} words")


if __name__ == '__main__':
    main()
