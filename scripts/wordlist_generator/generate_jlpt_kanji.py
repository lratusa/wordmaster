#!/usr/bin/env python3
"""
JLPT Kanji Word List Generator

Generates JLPT kanji word lists (N5-N1) from existing kanji data,
enriched with Gemini API for readings and example words.

Data Source:
- jlpt-kanji.json: Contains kanji with JLPT levels, stroke counts, frequency

Usage:
    python generate_jlpt_kanji.py --level n5          # Generate N5 kanji list
    python generate_jlpt_kanji.py --level all         # Generate all levels
    python generate_jlpt_kanji.py --level n3 --resume # Resume from checkpoint
    python generate_jlpt_kanji.py --level n5 --dry-run # Test with 10 kanji
"""

import argparse
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


# Configuration for each JLPT level
JLPT_CONFIGS = {
    'n5': {
        'level': 'N5',
        'output': 'jlpt_kanji_n5.json',
        'name': 'JLPT N5 漢字',
        'description': '日本语能力测试 N5 级别汉字',
        'difficulty': 1,
        'progress_file': 'jlpt_kanji_n5_progress.jsonl',
    },
    'n4': {
        'level': 'N4',
        'output': 'jlpt_kanji_n4.json',
        'name': 'JLPT N4 漢字',
        'description': '日本语能力测试 N4 级别汉字',
        'difficulty': 1,
        'progress_file': 'jlpt_kanji_n4_progress.jsonl',
    },
    'n3': {
        'level': 'N3',
        'output': 'jlpt_kanji_n3.json',
        'name': 'JLPT N3 漢字',
        'description': '日本语能力测试 N3 级别汉字',
        'difficulty': 2,
        'progress_file': 'jlpt_kanji_n3_progress.jsonl',
    },
    'n2': {
        'level': 'N2',
        'output': 'jlpt_kanji_n2.json',
        'name': 'JLPT N2 漢字',
        'description': '日本语能力测试 N2 级别汉字',
        'difficulty': 2,
        'progress_file': 'jlpt_kanji_n2_progress.jsonl',
    },
    'n1': {
        'level': 'N1',
        'output': 'jlpt_kanji_n1.json',
        'name': 'JLPT N1 漢字',
        'description': '日本语能力测试 N1 级别汉字',
        'difficulty': 3,
        'progress_file': 'jlpt_kanji_n1_progress.jsonl',
    },
}

# File paths
DATA_DIR = Path(__file__).parent / 'data' / 'jlpt'
KANJI_FILE = DATA_DIR / 'jlpt-kanji.json'
OUTPUT_DIR = Path(__file__).parent.parent.parent / 'assets' / 'wordlists' / 'japanese'
CHECKPOINT_DIR = Path(__file__).parent / 'checkpoints'

BATCH_SIZE = 10  # Smaller batch for kanji (more complex data per entry)


def load_jlpt_kanji(level: str) -> list[dict]:
    """
    Load kanji for a specific JLPT level from source JSON file.

    Returns list of dicts with: kanji, strokes, frequency, description
    """
    level_upper = level.upper()

    if not KANJI_FILE.exists():
        raise FileNotFoundError(f"Source file not found: {KANJI_FILE}")

    print(f"Loading {level_upper} kanji from: {KANJI_FILE}")

    with open(KANJI_FILE, encoding='utf-8') as f:
        all_kanji = json.load(f)

    # Filter by JLPT level
    kanji_list = []
    for entry in all_kanji:
        if entry.get('jlpt') != level_upper:
            continue

        kanji_list.append({
            'kanji': entry['kanji'],
            'strokes': entry.get('strokes'),
            'frequency': entry.get('frequency'),
            'description': entry.get('description', ''),
        })

    # Sort by frequency (most common first)
    kanji_list.sort(key=lambda x: x.get('frequency') or 9999)
    print(f"Loaded {len(kanji_list)} kanji for {level_upper}")
    return kanji_list


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
            kanji = item.get('kanji', '')
            if kanji:
                progress[kanji] = item
    print(f"Loaded {len(progress)} kanji from checkpoint")
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


def validate_kanji_entry(entry: dict) -> list[str]:
    """Validate kanji entry structure."""
    issues = []

    if not entry.get('kanji'):
        issues.append('missing kanji')
    if not entry.get('translation_cn'):
        issues.append('missing translation_cn')

    examples = entry.get('examples', [])
    if len(examples) < 2:
        issues.append(f'only {len(examples)} examples (need 2)')

    for i, ex in enumerate(examples):
        if not ex.get('word'):
            issues.append(f'example {i+1} missing word')
        if not ex.get('reading'):
            issues.append(f'example {i+1} missing reading')
        if not ex.get('translation_cn'):
            issues.append(f'example {i+1} missing translation_cn')

    return issues


def generate_jlpt_kanji_wordlist(
    level: str,
    config: dict,
    use_api: bool = True,
    resume: bool = True,
    dry_run: bool = False,
) -> dict:
    """Generate kanji list for a specific JLPT level."""
    print(f"\n{'='*60}")
    print(f"Generating JLPT {config['level']} kanji list")
    print(f"{'='*60}")

    progress_file = CHECKPOINT_DIR / config['progress_file']

    # Load source kanji
    source_kanji = load_jlpt_kanji(config['level'])

    if dry_run:
        print("DRY RUN: Processing only 10 kanji")
        source_kanji = source_kanji[:10]

    # Load progress
    progress = load_progress(progress_file) if resume else {}

    # Find kanji needing API
    kanji_needing_api = []
    for entry in source_kanji:
        if entry['kanji'] not in progress:
            kanji_needing_api.append(entry)

    print(f"Kanji needing API generation: {len(kanji_needing_api)}")

    # Generate with API
    if use_api and kanji_needing_api:
        try:
            client = GeminiClient()
            print(f"\nGenerating data for {len(kanji_needing_api)} kanji...")
            print(f"Batch size: {BATCH_SIZE}, Estimated batches: {(len(kanji_needing_api) + BATCH_SIZE - 1) // BATCH_SIZE}")

            for i, batch in enumerate(chunks(kanji_needing_api, BATCH_SIZE)):
                batch_num = i + 1
                total_batches = (len(kanji_needing_api) + BATCH_SIZE - 1) // BATCH_SIZE
                batch_kanji = [k['kanji'] for k in batch]
                print(f"\nBatch {batch_num}/{total_batches}: Processing {len(batch)} kanji: {batch_kanji[:5]}...")

                try:
                    results = client.generate_kanji_data(batch, config['level'])

                    valid_results = []
                    for item in results:
                        issues = validate_kanji_entry(item)
                        if issues:
                            print(f"  Warning: Issues with '{item.get('kanji', '?')}': {issues[:2]}")
                        valid_results.append(item)

                    for item in valid_results:
                        progress[item['kanji']] = item

                    save_progress(progress_file, valid_results)
                    print(f"  Saved {len(valid_results)} kanji to checkpoint")

                except Exception as e:
                    print(f"  Batch failed: {e}")
                    print("  Stopping to preserve progress. Run with --resume to continue.")
                    break

        except (ImportError, ValueError) as e:
            print(f"Warning: Cannot initialize Gemini client: {e}")
            print("Proceeding without API generation...")

    # Build final output
    print("\nBuilding final kanji list...")
    all_kanji = []

    for entry in source_kanji:
        kanji = entry['kanji']
        api_data = progress.get(kanji, {})

        kanji_entry = {
            'word': kanji,  # Use 'word' for consistency with app schema
            'translation_cn': api_data.get('translation_cn', ''),
            'onyomi': api_data.get('onyomi', ''),
            'kunyomi': api_data.get('kunyomi', ''),
            'strokes': entry.get('strokes'),
            'frequency': entry.get('frequency'),
            'jlpt_level': config['level'],
            'difficulty_level': config['difficulty'],
            'examples': api_data.get('examples', [])
        }

        all_kanji.append(kanji_entry)

    # Sort by frequency (most common first)
    all_kanji.sort(key=lambda x: x.get('frequency') or 9999)

    # Write output
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    output_data = {
        'name': config['name'],
        'language': 'ja',
        'description': f"{config['description']} ({len(all_kanji)}字)",
        'icon_name': 'translate',
        'words': all_kanji
    }

    output_path = OUTPUT_DIR / config['output']
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2)

    print(f"Kanji list written to: {output_path}")

    # Statistics
    stats = {
        'total_kanji': len(all_kanji),
        'with_translation': sum(1 for k in all_kanji if k.get('translation_cn')),
        'with_onyomi': sum(1 for k in all_kanji if k.get('onyomi')),
        'with_kunyomi': sum(1 for k in all_kanji if k.get('kunyomi')),
        'with_examples': sum(1 for k in all_kanji if len(k.get('examples', [])) >= 2),
    }

    print(f"\nStatistics for JLPT {config['level']}:")
    print(f"  Total kanji: {stats['total_kanji']}")
    print(f"  With translation: {stats['with_translation']} ({100*stats['with_translation']/stats['total_kanji']:.1f}%)")
    print(f"  With onyomi: {stats['with_onyomi']} ({100*stats['with_onyomi']/stats['total_kanji']:.1f}%)")
    print(f"  With kunyomi: {stats['with_kunyomi']} ({100*stats['with_kunyomi']/stats['total_kanji']:.1f}%)")
    print(f"  With 2+ examples: {stats['with_examples']} ({100*stats['with_examples']/stats['total_kanji']:.1f}%)")

    return stats


def main():
    parser = argparse.ArgumentParser(description='Generate JLPT kanji word lists')
    parser.add_argument(
        '--level', '-l',
        choices=list(JLPT_CONFIGS.keys()) + ['all'],
        required=True,
        help='JLPT level to generate (n5-n1 or all)'
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
        help='Process only 10 kanji for testing'
    )

    args = parser.parse_args()

    levels = list(JLPT_CONFIGS.keys()) if args.level == 'all' else [args.level]

    print(f"Will generate JLPT kanji lists for: {', '.join(levels)}")

    all_stats = {}
    for level in levels:
        config = JLPT_CONFIGS[level]
        stats = generate_jlpt_kanji_wordlist(
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
            print(f"JLPT {level.upper()}: {stats['total_kanji']} kanji")


if __name__ == '__main__':
    main()
