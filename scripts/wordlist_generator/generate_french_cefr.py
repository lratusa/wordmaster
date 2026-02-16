#!/usr/bin/env python3
"""
French CEFR Word List Generator

Generates French CEFR vocabulary word lists (A1-C2) using Gemini API
for French vocabulary, IPA phonetics, Chinese translations, and example sentences.

Data Sources:
- AI-generated French vocabulary based on CEFR level guidelines
- Frequency-based selection for authentic CEFR-appropriate words

Usage:
    python generate_french_cefr.py --level a1          # Generate A1 word list
    python generate_french_cefr.py --level all         # Generate all levels
    python generate_french_cefr.py --level b1 --resume # Resume from checkpoint
    python generate_french_cefr.py --level a1 --dry-run # Test with 10 words
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


# Configuration for each CEFR level
FRENCH_CEFR_CONFIGS = {
    'a1': {
        'level': 'A1',
        'output': 'cefr_a1.json',
        'name': 'CEFR A1 法语入门',
        'description': '法语 A1 级别词汇（入门级）',
        'target_count': 500,
        'difficulty': 1,
        'progress_file': 'french_cefr_a1_progress.jsonl',
    },
    'a2': {
        'level': 'A2',
        'output': 'cefr_a2.json',
        'name': 'CEFR A2 法语基础',
        'description': '法语 A2 级别词汇（基础级）',
        'target_count': 1000,
        'difficulty': 1,
        'progress_file': 'french_cefr_a2_progress.jsonl',
    },
    'b1': {
        'level': 'B1',
        'output': 'cefr_b1.json',
        'name': 'CEFR B1 法语中级',
        'description': '法语 B1 级别词汇（中级）',
        'target_count': 1500,
        'difficulty': 2,
        'progress_file': 'french_cefr_b1_progress.jsonl',
    },
    'b2': {
        'level': 'B2',
        'output': 'cefr_b2.json',
        'name': 'CEFR B2 法语中高级',
        'description': '法语 B2 级别词汇（中高级）',
        'target_count': 2000,
        'difficulty': 2,
        'progress_file': 'french_cefr_b2_progress.jsonl',
    },
    'c1': {
        'level': 'C1',
        'output': 'cefr_c1.json',
        'name': 'CEFR C1 法语高级',
        'description': '法语 C1 级别词汇（高级）',
        'target_count': 2500,
        'difficulty': 3,
        'progress_file': 'french_cefr_c1_progress.jsonl',
    },
    'c2': {
        'level': 'C2',
        'output': 'cefr_c2.json',
        'name': 'CEFR C2 法语精通',
        'description': '法语 C2 级别词汇（精通级）',
        'target_count': 3000,
        'difficulty': 3,
        'progress_file': 'french_cefr_c2_progress.jsonl',
    },
}

# File paths
DATA_DIR = Path(__file__).parent / 'data' / 'french'
OUTPUT_DIR = Path(__file__).parent.parent.parent / 'assets' / 'wordlists' / 'french'
CHECKPOINT_DIR = Path(__file__).parent / 'checkpoints'

BATCH_SIZE = 15


def generate_french_vocabulary_list(level: str, target_count: int) -> list[str]:
    """
    Generate a list of French words appropriate for the given CEFR level.

    Uses Gemini API to generate frequency-based vocabulary suitable for each level.
    Returns a list of French words (headwords only).
    """
    client = GeminiClient()

    level_descriptions = {
        'A1': 'very basic everyday words (greetings, numbers, family, colors, food, common verbs like être/avoir/aller)',
        'A2': 'elementary words for daily situations (shopping, transport, weather, hobbies, simple past tense)',
        'B1': 'intermediate words for familiar topics (work, travel, opinions, conditional tense)',
        'B2': 'upper-intermediate words for abstract topics (current events, debates, complex grammar)',
        'C1': 'advanced words for sophisticated expression (academic, professional, nuanced meanings)',
        'C2': 'near-native words including idioms, literary terms, specialized vocabulary',
    }

    prompt = f"""Generate a list of exactly {target_count} French words appropriate for CEFR level {level}.

Level description: {level_descriptions.get(level, 'general French vocabulary')}

Requirements:
1. Return ONLY a JSON array of French words (no explanations)
2. Include common words at this level (frequency-based)
3. Cover diverse topics: daily life, verbs, adjectives, nouns
4. Include words with French special characters (é, è, ê, ë, ç, œ, ù, â, etc.)
5. For A1: Include être, avoir, aller, faire, français, cœur, etc.
6. Format: ["word1", "word2", "word3", ...]

Example format:
["être", "avoir", "aller", "faire", "français", "maison", "école", ...]

Generate {target_count} words now:"""

    print(f"Requesting {target_count} French words for level {level} from Gemini...")

    response = client.generate_response(prompt)

    # Parse JSON array from response
    try:
        # Try to extract JSON array from response
        import re
        json_match = re.search(r'\[.*\]', response, re.DOTALL)
        if json_match:
            words = json.loads(json_match.group())
            print(f"Generated {len(words)} French words")
            return words[:target_count]  # Limit to target count
        else:
            raise ValueError("No JSON array found in response")
    except Exception as e:
        print(f"Error parsing Gemini response: {e}")
        print(f"Response preview: {response[:200]}...")
        return []


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


def generate_french_cefr_wordlist(
    level: str,
    config: dict,
    use_api: bool = True,
    resume: bool = True,
    dry_run: bool = False,
) -> dict:
    """Generate French word list for a specific CEFR level."""
    print(f"\n{'='*60}")
    print(f"Generating French CEFR {config['level']} word list")
    print(f"{'='*60}")

    progress_file = CHECKPOINT_DIR / config['progress_file']

    # Load progress
    progress = load_progress(progress_file) if resume else {}

    # Generate French vocabulary list if needed
    if not progress or len(progress) < config['target_count']:
        if use_api:
            try:
                client = GeminiClient()
                print(f"Generating {config['target_count']} French words for level {config['level']}...")
                french_words = generate_french_vocabulary_list(config['level'], config['target_count'])

                if not french_words:
                    print("Error: Failed to generate French vocabulary list")
                    return {}

                print(f"Generated {len(french_words)} French words")
            except Exception as e:
                print(f"Error generating vocabulary: {e}")
                return {}
        else:
            print("Error: --no-api mode not supported for French generation (no word source file)")
            return {}
    else:
        # Extract words from progress
        french_words = [entry['word'] for entry in progress.values()]
        print(f"Using {len(french_words)} words from checkpoint")

    if dry_run:
        print("DRY RUN: Processing only 10 words")
        french_words = french_words[:10]

    # Find words needing API enrichment
    words_needing_api = []
    for word in french_words:
        word_lower = word.lower()
        if word_lower not in progress:
            words_needing_api.append(word)

    print(f"Words needing API enrichment: {len(words_needing_api)}")

    # Generate enriched data with API
    if use_api and words_needing_api:
        try:
            client = GeminiClient()
            print(f"\nGenerating data for {len(words_needing_api)} French words...")
            print(f"Batch size: {BATCH_SIZE}, Estimated batches: {(len(words_needing_api) + BATCH_SIZE - 1) // BATCH_SIZE}")

            for i, batch in enumerate(chunks(words_needing_api, BATCH_SIZE)):
                batch_num = i + 1
                total_batches = (len(words_needing_api) + BATCH_SIZE - 1) // BATCH_SIZE
                print(f"\nBatch {batch_num}/{total_batches}: Processing {len(batch)} words: {batch[:3]}...")

                try:
                    # Generate French word data (phonetic, translation, examples)
                    results = client.generate_french_word_data(batch, config['level'])

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
    print("\nBuilding final French word list...")
    all_words = []

    for word in french_words:
        word_lower = word.lower()
        api_data = progress.get(word_lower, {})

        word_entry = {
            'word': word,
            'translation_cn': api_data.get('translation_cn', ''),
            'phonetic': api_data.get('phonetic', ''),
            'examples': api_data.get('examples', [])
        }

        all_words.append(word_entry)

    # Sort alphabetically
    all_words.sort(key=lambda x: x['word'].lower())

    # Write output
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    output_data = {
        'name': config['name'],
        'language': 'fr',
        'description': f"{config['description']} ({len(all_words)}词)",
        'category': 'cefr',
        'level': config['level'],
        'words': all_words
    }

    output_path = OUTPUT_DIR / config['output']
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2)

    print(f"French word list written to: {output_path}")

    # Statistics
    stats = {
        'total_words': len(all_words),
        'with_translation': sum(1 for w in all_words if w.get('translation_cn')),
        'with_phonetic': sum(1 for w in all_words if w.get('phonetic')),
        'with_examples': sum(1 for w in all_words if len(w.get('examples', [])) >= 2),
    }

    print(f"\nStatistics for French CEFR {config['level']}:")
    print(f"  Total words: {stats['total_words']}")
    print(f"  With translation: {stats['with_translation']} ({100*stats['with_translation']/stats['total_words']:.1f}%)")
    print(f"  With phonetic: {stats['with_phonetic']} ({100*stats['with_phonetic']/stats['total_words']:.1f}%)")
    print(f"  With 2+ examples: {stats['with_examples']} ({100*stats['with_examples']/stats['total_words']:.1f}%)")

    return stats


def main():
    parser = argparse.ArgumentParser(description='Generate French CEFR word lists')
    parser.add_argument(
        '--level', '-l',
        choices=list(FRENCH_CEFR_CONFIGS.keys()) + ['all'],
        required=True,
        help='CEFR level to generate (a1-c2 or all)'
    )
    parser.add_argument(
        '--no-api',
        action='store_true',
        help='Skip API calls (not recommended for French)'
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

    levels = list(FRENCH_CEFR_CONFIGS.keys()) if args.level == 'all' else [args.level]

    print(f"Will generate French CEFR word lists for: {', '.join(levels)}")

    all_stats = {}
    for level in levels:
        config = FRENCH_CEFR_CONFIGS[level]
        stats = generate_french_cefr_wordlist(
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
            print(f"French CEFR {level.upper()}: {stats['total_words']} words")


if __name__ == '__main__':
    main()
