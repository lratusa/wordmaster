#!/usr/bin/env python3
"""
Japanese School Kanji Word List Generator

Generates kanji word lists based on official Japanese school curriculum:
- Elementary School (小学校): Grades 1-6 (1,026 kanji total)
- Middle School (中学校): Additional kanji for middle school (~600 kanji)
- High School (高等学校): Remaining joyo kanji (~510 kanji)

Data Sources:
- kyoiku-kanji-2017.csv: Elementary school kanji by grade (2017 curriculum)
- joyo-kanji.csv: Complete joyo kanji list (2,136 kanji)

Usage:
    python generate_school_kanji.py --level grade1         # Generate grade 1
    python generate_school_kanji.py --level elementary     # Generate all elementary grades
    python generate_school_kanji.py --level middle         # Generate middle school
    python generate_school_kanji.py --level high           # Generate high school
    python generate_school_kanji.py --level all            # Generate all levels
    python generate_school_kanji.py --level grade3 --resume # Resume from checkpoint
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


# Configuration for each school level
SCHOOL_CONFIGS = {
    'grade1': {
        'grade': 1,
        'output': 'school_kanji_grade1.json',
        'name': '小学1年生 漢字',
        'description': '小学校1年级汉字',
        'difficulty': 1,
        'progress_file': 'school_kanji_grade1_progress.jsonl',
    },
    'grade2': {
        'grade': 2,
        'output': 'school_kanji_grade2.json',
        'name': '小学2年生 漢字',
        'description': '小学校2年级汉字',
        'difficulty': 1,
        'progress_file': 'school_kanji_grade2_progress.jsonl',
    },
    'grade3': {
        'grade': 3,
        'output': 'school_kanji_grade3.json',
        'name': '小学3年生 漢字',
        'description': '小学校3年级汉字',
        'difficulty': 1,
        'progress_file': 'school_kanji_grade3_progress.jsonl',
    },
    'grade4': {
        'grade': 4,
        'output': 'school_kanji_grade4.json',
        'name': '小学4年生 漢字',
        'description': '小学校4年级汉字',
        'difficulty': 2,
        'progress_file': 'school_kanji_grade4_progress.jsonl',
    },
    'grade5': {
        'grade': 5,
        'output': 'school_kanji_grade5.json',
        'name': '小学5年生 漢字',
        'description': '小学校5年级汉字',
        'difficulty': 2,
        'progress_file': 'school_kanji_grade5_progress.jsonl',
    },
    'grade6': {
        'grade': 6,
        'output': 'school_kanji_grade6.json',
        'name': '小学6年生 漢字',
        'description': '小学校6年级汉字',
        'difficulty': 2,
        'progress_file': 'school_kanji_grade6_progress.jsonl',
    },
    'middle': {
        'grade': 'middle',
        'output': 'school_kanji_middle.json',
        'name': '中学校 漢字',
        'description': '中学校汉字',
        'difficulty': 2,
        'progress_file': 'school_kanji_middle_progress.jsonl',
    },
    'high': {
        'grade': 'high',
        'output': 'school_kanji_high.json',
        'name': '高等学校 漢字',
        'description': '高等学校汉字',
        'difficulty': 3,
        'progress_file': 'school_kanji_high_progress.jsonl',
    },
}

# Level groups
ELEMENTARY_LEVELS = ['grade1', 'grade2', 'grade3', 'grade4', 'grade5', 'grade6']
ALL_LEVELS = ELEMENTARY_LEVELS + ['middle', 'high']

# File paths
DATA_DIR = Path(__file__).parent / 'data'
KYOIKU_FILE = DATA_DIR / 'kyoiku-kanji-2017.csv'
JOYO_FILE = DATA_DIR / 'joyo-kanji.csv'
OUTPUT_DIR = Path(__file__).parent.parent.parent / 'assets' / 'wordlists' / 'japanese'
CHECKPOINT_DIR = Path(__file__).parent / 'checkpoints'

BATCH_SIZE = 10


def load_kyoiku_kanji() -> dict[int, list[str]]:
    """Load elementary school kanji grouped by grade."""
    if not KYOIKU_FILE.exists():
        raise FileNotFoundError(f"Kyoiku kanji file not found: {KYOIKU_FILE}")

    grades = {i: [] for i in range(1, 7)}

    with open(KYOIKU_FILE, encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            kanji = row['Kanji']
            grade = int(row['Grade_2017'])
            if grade in grades:
                grades[grade].append(kanji)

    return grades


def load_joyo_kanji() -> list[str]:
    """Load all joyo kanji."""
    if not JOYO_FILE.exists():
        raise FileNotFoundError(f"Joyo kanji file not found: {JOYO_FILE}")

    kanji_list = []

    with open(JOYO_FILE, encoding='utf-8') as f:
        reader = csv.reader(f)
        for row in reader:
            if len(row) >= 2:
                kanji_list.append(row[1])  # Second column is the kanji

    return kanji_list


def load_school_kanji(level: str) -> list[dict]:
    """
    Load kanji for a specific school level.

    Returns list of dicts with: kanji
    """
    kyoiku_grades = load_kyoiku_kanji()

    if level.startswith('grade'):
        # Elementary grades
        grade = int(level.replace('grade', ''))
        kanji_list = kyoiku_grades.get(grade, [])
        print(f"Loaded {len(kanji_list)} kanji for grade {grade}")

    elif level == 'middle':
        # Middle school: roughly first half of non-kyoiku joyo kanji (by order)
        all_joyo = set(load_joyo_kanji())
        all_kyoiku = set()
        for grade_list in kyoiku_grades.values():
            all_kyoiku.update(grade_list)

        secondary_kanji = [k for k in load_joyo_kanji() if k not in all_kyoiku]
        # Take first ~55% for middle school (roughly 600 out of 1110)
        split_point = int(len(secondary_kanji) * 0.55)
        kanji_list = secondary_kanji[:split_point]
        print(f"Loaded {len(kanji_list)} kanji for middle school")

    elif level == 'high':
        # High school: remaining joyo kanji
        all_joyo = set(load_joyo_kanji())
        all_kyoiku = set()
        for grade_list in kyoiku_grades.values():
            all_kyoiku.update(grade_list)

        secondary_kanji = [k for k in load_joyo_kanji() if k not in all_kyoiku]
        split_point = int(len(secondary_kanji) * 0.55)
        kanji_list = secondary_kanji[split_point:]
        print(f"Loaded {len(kanji_list)} kanji for high school")

    else:
        raise ValueError(f"Unknown level: {level}")

    return [{'kanji': k} for k in kanji_list]


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

    return issues


def generate_school_kanji_wordlist(
    level: str,
    config: dict,
    use_api: bool = True,
    resume: bool = True,
    dry_run: bool = False,
) -> dict:
    """Generate kanji list for a specific school level."""
    print(f"\n{'='*60}")
    print(f"Generating {config['name']}")
    print(f"{'='*60}")

    progress_file = CHECKPOINT_DIR / config['progress_file']

    # Load source kanji
    source_kanji = load_school_kanji(level)

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

            # Determine school level for API prompt
            if level.startswith('grade'):
                grade_num = int(level.replace('grade', ''))
                jlpt_level = 'N5' if grade_num <= 2 else ('N4' if grade_num <= 4 else 'N3')
            elif level == 'middle':
                jlpt_level = 'N3'
            else:
                jlpt_level = 'N2'

            print(f"\nGenerating data for {len(kanji_needing_api)} kanji...")
            print(f"Batch size: {BATCH_SIZE}, Estimated batches: {(len(kanji_needing_api) + BATCH_SIZE - 1) // BATCH_SIZE}")

            for i, batch in enumerate(chunks(kanji_needing_api, BATCH_SIZE)):
                batch_num = i + 1
                total_batches = (len(kanji_needing_api) + BATCH_SIZE - 1) // BATCH_SIZE
                batch_kanji = [k['kanji'] for k in batch]
                print(f"\nBatch {batch_num}/{total_batches}: Processing {len(batch)} kanji: {batch_kanji[:5]}...")

                try:
                    # Use the kanji generation method
                    batch_with_desc = [{'kanji': k['kanji'], 'description': ''} for k in batch]
                    results = client.generate_kanji_data(batch_with_desc, jlpt_level)

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
            'word': kanji,
            'translation_cn': api_data.get('translation_cn', ''),
            'onyomi': api_data.get('onyomi', ''),
            'kunyomi': api_data.get('kunyomi', ''),
            'school_level': config['name'],
            'difficulty_level': config['difficulty'],
            'examples': api_data.get('examples', [])
        }

        all_kanji.append(kanji_entry)

    # Write output
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    output_data = {
        'name': config['name'],
        'language': 'ja',
        'description': f"{config['description']} ({len(all_kanji)}字)",
        'icon_name': 'school',
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

    print(f"\nStatistics for {config['name']}:")
    print(f"  Total kanji: {stats['total_kanji']}")
    if stats['total_kanji'] > 0:
        print(f"  With translation: {stats['with_translation']} ({100*stats['with_translation']/stats['total_kanji']:.1f}%)")
        print(f"  With onyomi: {stats['with_onyomi']} ({100*stats['with_onyomi']/stats['total_kanji']:.1f}%)")
        print(f"  With kunyomi: {stats['with_kunyomi']} ({100*stats['with_kunyomi']/stats['total_kanji']:.1f}%)")
        print(f"  With 2+ examples: {stats['with_examples']} ({100*stats['with_examples']/stats['total_kanji']:.1f}%)")

    return stats


def main():
    parser = argparse.ArgumentParser(description='Generate Japanese school kanji word lists')
    parser.add_argument(
        '--level', '-l',
        choices=list(SCHOOL_CONFIGS.keys()) + ['elementary', 'all'],
        required=True,
        help='School level to generate'
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

    # Determine levels to generate
    if args.level == 'all':
        levels = ALL_LEVELS
    elif args.level == 'elementary':
        levels = ELEMENTARY_LEVELS
    else:
        levels = [args.level]

    print(f"Will generate school kanji lists for: {', '.join(levels)}")

    all_stats = {}
    for level in levels:
        config = SCHOOL_CONFIGS[level]
        stats = generate_school_kanji_wordlist(
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
            print(f"{SCHOOL_CONFIGS[level]['name']}: {stats['total_kanji']} kanji")


if __name__ == '__main__':
    main()
