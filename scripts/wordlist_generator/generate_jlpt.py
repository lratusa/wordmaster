#!/usr/bin/env python3
"""
JLPT Word List Generator

Generates Japanese word lists for JLPT N5-N1 levels.
Uses elzup/jlpt-word-list as source data, enriched with Gemini API
for Chinese translations and example sentences.

Usage:
    python generate_jlpt.py --level n5           # Generate N5 word list
    python generate_jlpt.py --level n5 --resume  # Resume from checkpoint
    python generate_jlpt.py --level all          # Generate all levels
    python generate_jlpt.py --no-api             # Skip API calls
    python generate_jlpt.py --dry-run            # Test with 10 words only
"""

import argparse
import csv
import json
import os
import re
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


# Configuration for each JLPT level
JLPT_CONFIGS = {
    'n5': {
        'level_tags': ['JLPT_5', 'JLPT_N5'],
        'output': 'jlpt_n5.json',
        'name': 'JLPT N5 基础日语',
        'desc': '日本语能力测试 N5 级别基础词汇',
        'difficulty': 1,
    },
    'n4': {
        'level_tags': ['JLPT_4', 'JLPT_N4'],
        'output': 'jlpt_n4.json',
        'name': 'JLPT N4 初级日语',
        'desc': '日本语能力测试 N4 级别初级词汇',
        'difficulty': 2,
    },
    'n3': {
        'level_tags': ['JLPT_3', 'JLPT_N3'],
        'output': 'jlpt_n3.json',
        'name': 'JLPT N3 中级日语',
        'desc': '日本语能力测试 N3 级别中级词汇',
        'difficulty': 2,
    },
    'n2': {
        'level_tags': ['JLPT_2', 'JLPT_N2'],
        'output': 'jlpt_n2.json',
        'name': 'JLPT N2 中高级日语',
        'desc': '日本语能力测试 N2 级别中高级词汇',
        'difficulty': 3,
    },
    'n1': {
        'level_tags': ['JLPT_1', 'JLPT_N1'],
        'output': 'jlpt_n1.json',
        'name': 'JLPT N1 高级日语',
        'desc': '日本语能力测试 N1 级别高级词汇',
        'difficulty': 3,
    },
}

SOURCE_CSV = Path(__file__).parent / 'data' / 'jlpt' / 'all.csv'
OUTPUT_DIR = Path(__file__).parent.parent.parent / 'assets' / 'wordlists' / 'japanese'
CHECKPOINT_DIR = Path(__file__).parent / 'checkpoints'
BATCH_SIZE = 15


def load_source_data(level: str) -> list[dict]:
    """Load and filter source data for specific JLPT level."""
    print(f"Loading source data from: {SOURCE_CSV}")

    config = JLPT_CONFIGS[level]
    level_tags = set(config['level_tags'])

    words = []
    seen = set()

    with open(SOURCE_CSV, encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            expression = row.get('expression', '').strip()
            reading = row.get('reading', '').strip()
            meaning = row.get('meaning', '').strip()
            tags = row.get('tags', '')

            if not expression or not reading:
                continue

            # Check if this entry matches our level
            row_tags = set(tags.split())
            if not row_tags & level_tags:
                continue

            # Deduplicate by expression
            if expression in seen:
                continue
            seen.add(expression)

            words.append({
                'word': expression,
                'reading': reading,
                'meaning_en': meaning,
            })

    print(f"Loaded {len(words)} unique words for {level.upper()}")
    return words


def get_jlpt_level_display(level: str) -> str:
    """Get display format for JLPT level."""
    return level.upper()  # N5, N4, etc.


def normalize_part_of_speech(meaning: str) -> str:
    """Extract part of speech from meaning if present."""
    # Common patterns in English meanings
    pos_patterns = {
        r'\(n\)': '名',
        r'\(v\)': '动',
        r'\(adj\)': '形',
        r'\(adv\)': '副',
        r'\bverb\b': '动',
        r'\bnoun\b': '名',
        r'\badjective\b': '形',
        r'\badverb\b': '副',
        r'\bparticle\b': '助',
        r'\bconjunction\b': '接',
        r'\binterjection\b': '感',
        r'\bto\s+\w+': '动',  # "to do" patterns indicate verb
    }

    meaning_lower = meaning.lower()
    for pattern, pos in pos_patterns.items():
        if re.search(pattern, meaning_lower):
            return pos

    return ''


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
            word = item.get('word', '')
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


def validate_japanese_entry(entry: dict) -> list[str]:
    """Validate a Japanese word entry."""
    issues = []
    word = entry.get('word', '<unknown>')

    if not entry.get('word'):
        issues.append("Missing 'word' field")
    if not entry.get('translation_cn'):
        issues.append(f"Missing 'translation_cn' for: {word}")

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


def generate_wordlist(
    level: str,
    use_api: bool = True,
    resume: bool = True,
    dry_run: bool = False,
) -> dict:
    """Generate word list for a specific JLPT level."""
    config = JLPT_CONFIGS[level]

    print(f"\n{'='*60}")
    print(f"Generating JLPT {level.upper()} word list")
    print(f"{'='*60}")

    progress_file = CHECKPOINT_DIR / f'jlpt_{level}_progress.jsonl'

    # Load source data
    source_data = load_source_data(level)

    if not source_data:
        print(f"Error: No words found for {level.upper()}")
        return {}

    if dry_run:
        print("DRY RUN: Processing only 10 words")
        source_data = source_data[:10]

    # Load progress
    progress = load_progress(progress_file) if resume else {}

    # Find words needing API enrichment
    words_needing_api = []
    for entry in source_data:
        if entry['word'] not in progress:
            words_needing_api.append(entry)

    print(f"Words needing API generation: {len(words_needing_api)}")

    # Generate with API
    if use_api and words_needing_api:
        try:
            client = GeminiClient()
            print(f"\nGenerating data for {len(words_needing_api)} words...")
            print(f"Batch size: {BATCH_SIZE}, Estimated batches: {len(words_needing_api) // BATCH_SIZE + 1}")

            for i, batch in enumerate(chunks(words_needing_api, BATCH_SIZE)):
                batch_words = [w['word'] for w in batch]
                print(f"\nBatch {i+1}: Processing {len(batch)} words: {batch_words[:3]}...")

                try:
                    results = client.generate_japanese_enrichment(batch)

                    valid_results = []
                    for item in results:
                        issues = validate_japanese_entry(item)
                        if issues:
                            print(f"  Warning: Issues with '{item.get('word', '?')}': {issues[:2]}")
                        valid_results.append(item)

                    for item in valid_results:
                        progress[item['word']] = item

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

    for entry in source_data:
        word = entry['word']
        api_data = progress.get(word, {})

        word_entry = {
            'word': word,
            'translation_cn': api_data.get('translation_cn', ''),
            'part_of_speech': normalize_part_of_speech(entry.get('meaning_en', '')),
            'reading': entry['reading'],
            'jlpt_level': get_jlpt_level_display(level),
            'difficulty_level': config['difficulty'],
            'examples': api_data.get('examples', [])
        }

        # Only include words with Chinese translation
        if word_entry['translation_cn']:
            all_words.append(word_entry)
        else:
            # Fallback: use English meaning if no Chinese translation
            if entry.get('meaning_en'):
                word_entry['translation_cn'] = entry['meaning_en']
                word_entry['examples'] = []  # No examples available
                all_words.append(word_entry)

    # Sort by reading (hiragana order)
    all_words.sort(key=lambda x: x['reading'])

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Write output
    output = {
        'name': config['name'],
        'language': 'ja',
        'description': f"{config['desc']} ({len(all_words)}词)",
        'icon_name': 'language',
        'words': all_words
    }

    output_path = OUTPUT_DIR / config['output']
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print(f"Output written to: {output_path}")

    # Statistics
    stats = {
        'total_words': len(all_words),
        'with_translation': sum(1 for w in all_words if w.get('translation_cn')),
        'with_examples': sum(1 for w in all_words if len(w.get('examples', [])) >= 2),
    }

    print(f"\nStatistics for JLPT {level.upper()}:")
    print(f"  Total words: {stats['total_words']}")
    print(f"  With Chinese translation: {stats['with_translation']} ({100*stats['with_translation']/max(1,stats['total_words']):.1f}%)")
    print(f"  With 2+ examples: {stats['with_examples']} ({100*stats['with_examples']/max(1,stats['total_words']):.1f}%)")

    return stats


def main():
    parser = argparse.ArgumentParser(description='Generate JLPT word lists')
    parser.add_argument(
        '--level', '-l',
        choices=list(JLPT_CONFIGS.keys()) + ['all'],
        default='n5',
        help='JLPT level to generate (default: n5)'
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

    levels = list(JLPT_CONFIGS.keys()) if args.level == 'all' else [args.level]

    print(f"Will generate word lists for: {', '.join(l.upper() for l in levels)}")

    all_stats = {}
    for level in levels:
        stats = generate_wordlist(
            level=level,
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
            print(f"JLPT {level.upper()}: {stats.get('total_words', 0)} words "
                  f"(with examples: {stats.get('with_examples', 0)})")


if __name__ == '__main__':
    main()
