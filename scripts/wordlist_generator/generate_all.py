#!/usr/bin/env python3
"""
Batch Word List Generator

Generates multiple word lists from KyleBing/english-vocabulary source data.
Supports: CET-4, CET-6, 考研, SAT, 中考, 高考, TOEFL

Usage:
    python generate_all.py                    # Generate all word lists
    python generate_all.py --exam cet6        # Generate specific exam
    python generate_all.py --exam cet6 kaoyan # Generate multiple exams
    python generate_all.py --no-api           # Skip API calls
    python generate_all.py --dry-run          # Test with 10 words only
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


# Configuration for each exam type
EXAM_CONFIGS = {
    'zhongkao': {
        'source': 'D:/temp/english-vocabulary/json/1-初中-顺序.json',
        'output_core': 'zhongkao_core.json',
        'output_full': 'zhongkao_full.json',
        'name_core': '中考核心词汇',
        'name_full': '中考完整词汇',
        'desc_core': '中考英语核心高频词汇',
        'desc_full': '中考英语大纲完整词汇表',
        'progress_file': 'zhongkao_progress.jsonl',
    },
    'gaokao': {
        'source': 'D:/temp/english-vocabulary/json/2-高中-顺序.json',
        'output_core': 'gaokao_core.json',
        'output_full': 'gaokao_full.json',
        'name_core': '高考核心词汇',
        'name_full': '高考完整词汇',
        'desc_core': '高考英语核心高频词汇',
        'desc_full': '高考英语大纲完整词汇表',
        'progress_file': 'gaokao_progress.jsonl',
    },
    'cet4': {
        'source': 'D:/temp/english-vocabulary/json/3-CET4-顺序.json',
        'output_core': 'cet4_core.json',
        'output_full': 'cet4_full.json',
        'name_core': 'CET-4 四级核心词汇',
        'name_full': 'CET-4 四级完整词汇',
        'desc_core': '大学英语四级考试核心高频词汇',
        'desc_full': '大学英语四级考试完整词汇表',
        'progress_file': 'cet4_progress.jsonl',
    },
    'cet6': {
        'source': 'D:/temp/english-vocabulary/json/4-CET6-顺序.json',
        'output_core': 'cet6_core.json',
        'output_full': 'cet6_full.json',
        'name_core': 'CET-6 六级核心词汇',
        'name_full': 'CET-6 六级完整词汇',
        'desc_core': '大学英语六级考试核心高频词汇',
        'desc_full': '大学英语六级考试完整词汇表',
        'progress_file': 'cet6_progress.jsonl',
    },
    'kaoyan': {
        'source': 'D:/temp/english-vocabulary/json/5-考研-顺序.json',
        'output_core': 'kaoyan_core.json',
        'output_full': 'kaoyan_full.json',
        'name_core': '考研核心词汇',
        'name_full': '考研完整词汇',
        'desc_core': '考研英语核心高频词汇',
        'desc_full': '考研英语大纲完整词汇表',
        'progress_file': 'kaoyan_progress.jsonl',
    },
    'toefl': {
        'source': 'D:/temp/english-vocabulary/json/6-托福-顺序.json',
        'output_core': 'toefl_core.json',
        'output_full': 'toefl_full.json',
        'name_core': 'TOEFL 托福核心词汇',
        'name_full': 'TOEFL 托福完整词汇',
        'desc_core': '托福考试核心词汇 - 与四六级重叠的高频词',
        'desc_full': '托福考试完整词汇',
        'progress_file': 'toefl_progress.jsonl',
    },
    'sat': {
        'source': 'D:/temp/english-vocabulary/json/7-SAT-顺序.json',
        'output_core': 'sat_core.json',
        'output_full': 'sat_full.json',
        'name_core': 'SAT 核心词汇',
        'name_full': 'SAT 完整词汇',
        'desc_core': 'SAT 考试核心高频词汇',
        'desc_full': 'SAT 考试完整词汇表',
        'progress_file': 'sat_progress.jsonl',
    },
}

# Base vocabulary for "core" classification (CET4 + CET6)
CET4_PATH = 'D:/temp/english-vocabulary/json/3-CET4-顺序.json'
CET6_PATH = 'D:/temp/english-vocabulary/json/4-CET6-顺序.json'

OUTPUT_DIR = Path(__file__).parent.parent.parent / 'assets' / 'wordlists' / 'english'
BATCH_SIZE = 15


def load_source_data(source_path: str) -> list[dict]:
    """Load and deduplicate source data."""
    print(f"Loading source data from: {source_path}")

    with open(source_path, encoding='utf-8') as f:
        raw_data = json.load(f)

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

        for trans in entry.get('translations', []):
            if trans not in word_map[word]['translations']:
                word_map[word]['translations'].append(trans)

        for phrase in entry.get('phrases', []):
            if phrase not in word_map[word]['phrases']:
                word_map[word]['phrases'].append(phrase)

    print(f"Loaded {len(word_map)} unique words (from {len(raw_data)} entries)")
    return list(word_map.values())


def load_core_word_set() -> set[str]:
    """Load CET4 + CET6 words as core vocabulary reference."""
    core_words = set()
    for path in [CET4_PATH, CET6_PATH]:
        if Path(path).exists():
            with open(path, encoding='utf-8') as f:
                for entry in json.load(f):
                    word = entry.get('word', '').strip().lower()
                    if word:
                        core_words.add(word)
    print(f"Loaded {len(core_words)} core reference words from CET4/6")
    return core_words


def normalize_part_of_speech(translations: list[dict]) -> str:
    """Normalize part of speech from translations."""
    pos_map = {
        'n': 'n.', 'v': 'v.', 'vt': 'vt.', 'vi': 'vi.',
        'adj': 'adj.', 'adv': 'adv.', 'prep': 'prep.',
        'conj': 'conj.', 'pron': 'pron.', 'int': 'int.',
        'art': 'art.', 'num': 'num.',
    }

    types = set()
    for trans in translations:
        pos = trans.get('type', '').lower().strip()
        for part in pos.replace('&', ' ').split():
            part = part.strip()
            if part in pos_map:
                types.add(pos_map[part])
            elif part:
                types.add(part + '.' if not part.endswith('.') else part)

    if not types:
        return ''

    order = ['n.', 'v.', 'vt.', 'vi.', 'adj.', 'adv.', 'prep.', 'conj.', 'pron.']
    sorted_types = sorted(types, key=lambda x: order.index(x) if x in order else 100)
    return '/'.join(sorted_types)


def combine_translations(translations: list[dict]) -> str:
    """Combine translations into a single string."""
    trans_texts = []
    for trans in translations:
        text = trans.get('translation', '').strip()
        if text and text not in trans_texts:
            trans_texts.append(text)
    return '；'.join(trans_texts)


def load_progress(progress_file: Path) -> dict[str, dict]:
    """Load progress from checkpoint file."""
    if not progress_file.exists():
        return {}
    if jsonlines is None:
        print("Warning: jsonlines not installed")
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
    with jsonlines.open(progress_file, mode='a') as writer:
        for item in items:
            writer.write(item)


def chunks(lst: list, n: int):
    """Yield successive n-sized chunks from lst."""
    for i in range(0, len(lst), n):
        yield lst[i:i + n]


def assign_difficulty(word: str) -> int:
    """Assign difficulty level based on word characteristics."""
    word_lower = word.lower()

    if len(word) <= 4:
        return 1
    if len(word) >= 10:
        return 3

    complex_suffixes = ['tion', 'sion', 'ment', 'ness', 'ical', 'ious', 'eous', 'able', 'ible']
    for suffix in complex_suffixes:
        if word_lower.endswith(suffix):
            return 3

    return 2


def generate_wordlist(
    exam: str,
    config: dict,
    use_api: bool = True,
    resume: bool = True,
    dry_run: bool = False,
    generate_core: bool = True,
    generate_full: bool = True,
    core_word_set: set[str] = None,
) -> dict:
    """Generate word list for a specific exam."""
    print(f"\n{'='*60}")
    print(f"Generating {exam.upper()} word list")
    print(f"{'='*60}")

    source_path = config['source']
    progress_file = Path(__file__).parent / config['progress_file']

    if not Path(source_path).exists():
        print(f"Error: Source file not found: {source_path}")
        return {}

    # Load source data
    source_data = load_source_data(source_path)

    if dry_run:
        print("DRY RUN: Processing only 10 words")
        source_data = source_data[:10]

    # Load progress
    progress = load_progress(progress_file) if resume else {}

    # Find words needing API
    words_needing_api = []
    for entry in source_data:
        word_lower = entry['word'].lower()
        if word_lower not in progress:
            words_needing_api.append(entry['word'])

    print(f"Words needing API generation: {len(words_needing_api)}")

    # Generate with API
    if use_api and words_needing_api:
        try:
            client = GeminiClient()
            print(f"\nGenerating data for {len(words_needing_api)} words...")
            print(f"Batch size: {BATCH_SIZE}, Estimated batches: {len(words_needing_api) // BATCH_SIZE + 1}")

            for i, batch in enumerate(chunks(words_needing_api, BATCH_SIZE)):
                print(f"\nBatch {i+1}: Processing {len(batch)} words: {batch[:3]}...")

                try:
                    results = client.generate_word_data(batch)

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
    core_words = []

    for entry in source_data:
        word = entry['word']
        word_lower = word.lower()
        api_data = progress.get(word_lower, {})

        word_entry = {
            'word': word,
            'translation_cn': combine_translations(entry.get('translations', [])),
            'part_of_speech': normalize_part_of_speech(entry.get('translations', [])),
            'phonetic': api_data.get('phonetic', ''),
            'difficulty_level': assign_difficulty(word),
            'examples': api_data.get('examples', [])
        }

        # Fallback examples from phrases
        if not word_entry['examples'] and entry.get('phrases'):
            word_entry['examples'] = [
                {
                    'sentence': phrase.get('phrase', ''),
                    'translation_cn': phrase.get('translation', '')
                }
                for phrase in entry.get('phrases', [])[:2]
                if phrase.get('phrase')
            ]

        all_words.append(word_entry)

        if core_word_set and word_lower in core_word_set:
            core_words.append(word_entry)

    # Sort alphabetically
    all_words.sort(key=lambda x: x['word'].lower())
    core_words.sort(key=lambda x: x['word'].lower())

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    stats = {}

    # Write core vocabulary
    if generate_core and core_words:
        core_output = {
            'name': config['name_core'],
            'language': 'en',
            'description': f"{config['desc_core']} ({len(core_words)}词)",
            'icon_name': 'school',
            'words': core_words
        }

        core_path = OUTPUT_DIR / config['output_core']
        with open(core_path, 'w', encoding='utf-8') as f:
            json.dump(core_output, f, ensure_ascii=False, indent=2)

        print(f"Core vocabulary written to: {core_path}")
        stats['core_words'] = len(core_words)

    # Write full vocabulary
    if generate_full:
        full_output = {
            'name': config['name_full'],
            'language': 'en',
            'description': f"{config['desc_full']} ({len(all_words)}词)",
            'icon_name': 'school',
            'words': all_words
        }

        full_path = OUTPUT_DIR / config['output_full']
        with open(full_path, 'w', encoding='utf-8') as f:
            json.dump(full_output, f, ensure_ascii=False, indent=2)

        print(f"Full vocabulary written to: {full_path}")
        stats['full_words'] = len(all_words)

    # Statistics
    stats['total_unique'] = len(all_words)
    stats['with_phonetic'] = sum(1 for w in all_words if w.get('phonetic'))
    stats['with_examples'] = sum(1 for w in all_words if len(w.get('examples', [])) >= 2)

    print(f"\nStatistics for {exam.upper()}:")
    print(f"  Total unique words: {stats['total_unique']}")
    if 'core_words' in stats:
        print(f"  Core vocabulary: {stats['core_words']} words")
    print(f"  With phonetic: {stats['with_phonetic']} ({100*stats['with_phonetic']/stats['total_unique']:.1f}%)")
    print(f"  With 2+ examples: {stats['with_examples']} ({100*stats['with_examples']/stats['total_unique']:.1f}%)")

    return stats


def main():
    parser = argparse.ArgumentParser(description='Batch generate word lists')
    parser.add_argument(
        '--exam', '-e',
        nargs='+',
        choices=list(EXAM_CONFIGS.keys()),
        help='Specific exams to generate (default: all)'
    )
    parser.add_argument(
        '--no-api',
        action='store_true',
        help='Skip API calls'
    )
    parser.add_argument(
        '--no-resume',
        action='store_true',
        help='Start fresh, ignoring checkpoints'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Process only 10 words for testing'
    )
    parser.add_argument(
        '--full-only',
        action='store_true',
        help='Generate only full vocabulary (skip core)'
    )

    args = parser.parse_args()

    exams = args.exam or list(EXAM_CONFIGS.keys())

    # Load core word set for classification
    core_word_set = load_core_word_set() if not args.full_only else set()

    print(f"Will generate word lists for: {', '.join(exams)}")

    all_stats = {}
    for exam in exams:
        config = EXAM_CONFIGS[exam]
        stats = generate_wordlist(
            exam=exam,
            config=config,
            use_api=not args.no_api,
            resume=not args.no_resume,
            dry_run=args.dry_run,
            generate_core=not args.full_only,
            generate_full=True,
            core_word_set=core_word_set,
        )
        all_stats[exam] = stats

    print(f"\n{'='*60}")
    print("SUMMARY")
    print(f"{'='*60}")
    for exam, stats in all_stats.items():
        if stats:
            print(f"{exam.upper()}: {stats.get('full_words', 0)} words (core: {stats.get('core_words', 0)})")


if __name__ == '__main__':
    main()
