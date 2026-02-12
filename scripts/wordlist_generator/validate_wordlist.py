#!/usr/bin/env python3
"""
Automated validation script for word list JSON files.

Usage:
    python validate_wordlist.py <path_to_wordlist.json>
    python validate_wordlist.py --all  # Validate all wordlists in assets
"""

import json
import sys
from pathlib import Path
from typing import Optional


def validate_wordlist(filepath: str, verbose: bool = True) -> dict:
    """
    Check word list quality automatically.

    Args:
        filepath: Path to the JSON wordlist file
        verbose: Print detailed output

    Returns:
        Validation result dictionary with:
        - total_words: Number of words
        - unique_words: Number of unique words
        - issues: List of issue strings
        - valid: Boolean indicating if all checks passed
    """
    with open(filepath, encoding='utf-8') as f:
        data = json.load(f)

    issues = []
    words = data.get('words', [])
    seen_words = set()

    # Check metadata
    if not data.get('name'):
        issues.append("Missing 'name' field in metadata")
    if not data.get('language'):
        issues.append("Missing 'language' field in metadata")

    for i, w in enumerate(words):
        word = w.get('word', '')
        line_ref = f"[{i+1}]"

        # Check duplicates
        word_lower = word.lower()
        if word_lower in seen_words:
            issues.append(f"{line_ref} Duplicate: {word}")
        seen_words.add(word_lower)

        # Check required fields
        if not word:
            issues.append(f"{line_ref} Missing 'word' field")
            continue

        if not w.get('translation_cn'):
            issues.append(f"{line_ref} Missing translation_cn: {word}")

        if not w.get('phonetic'):
            issues.append(f"{line_ref} Missing phonetic: {word}")

        # Check phonetic format (should start with /)
        phonetic = w.get('phonetic', '')
        if phonetic and not phonetic.startswith('/'):
            issues.append(f"{line_ref} Invalid phonetic format for: {word} (got: {phonetic})")

        # Check examples
        examples = w.get('examples', [])
        if len(examples) < 2:
            issues.append(f"{line_ref} <2 examples: {word} (has {len(examples)})")

        for j, ex in enumerate(examples):
            if not ex.get('sentence'):
                issues.append(f"{line_ref} Example {j+1} missing 'sentence' for: {word}")
            if not ex.get('translation_cn'):
                issues.append(f"{line_ref} Example {j+1} missing 'translation_cn' for: {word}")

        # Check part_of_speech (optional but recommended)
        if not w.get('part_of_speech'):
            # This is a warning, not an error
            pass

    result = {
        'filepath': filepath,
        'total_words': len(words),
        'unique_words': len(seen_words),
        'duplicate_count': len(words) - len(seen_words),
        'issues': issues,
        'valid': len(issues) == 0
    }

    if verbose:
        print(f"\n{'='*60}")
        print(f"Validation Report: {filepath}")
        print(f"{'='*60}")
        print(f"Total words: {result['total_words']}")
        print(f"Unique words: {result['unique_words']}")
        print(f"Duplicates: {result['duplicate_count']}")
        print(f"Issues found: {len(issues)}")

        if issues:
            print(f"\n{'Issues:':-^60}")
            # Show first 20 issues
            for issue in issues[:20]:
                print(f"  - {issue}")
            if len(issues) > 20:
                print(f"  ... and {len(issues) - 20} more issues")
        else:
            print("\n[OK] All checks passed!")

        print(f"{'='*60}\n")

    return result


def validate_all_wordlists(assets_dir: Optional[str] = None) -> dict:
    """
    Validate all wordlist JSON files in the assets directory.

    Args:
        assets_dir: Path to assets/wordlists directory

    Returns:
        Dictionary mapping filepath to validation results
    """
    if assets_dir is None:
        # Find assets directory relative to this script
        script_dir = Path(__file__).parent
        assets_dir = script_dir.parent.parent / 'assets' / 'wordlists'

    assets_path = Path(assets_dir)
    results = {}

    for json_file in assets_path.rglob('*.json'):
        results[str(json_file)] = validate_wordlist(str(json_file))

    # Summary
    print("\n" + "="*60)
    print("VALIDATION SUMMARY")
    print("="*60)

    all_valid = True
    for filepath, result in results.items():
        status = "[OK]" if result['valid'] else "[FAIL]"
        all_valid = all_valid and result['valid']
        print(f"{status} {Path(filepath).name}: {result['total_words']} words, {len(result['issues'])} issues")

    print("="*60)
    if all_valid:
        print("All wordlists passed validation!")
    else:
        print("Some wordlists have issues. See details above.")

    return results


def main():
    if len(sys.argv) < 2:
        print("Usage: python validate_wordlist.py <path_to_wordlist.json>")
        print("       python validate_wordlist.py --all")
        sys.exit(1)

    arg = sys.argv[1]

    if arg == '--all':
        results = validate_all_wordlists()
        all_valid = all(r['valid'] for r in results.values())
        sys.exit(0 if all_valid else 1)
    else:
        result = validate_wordlist(arg)
        sys.exit(0 if result['valid'] else 1)


if __name__ == '__main__':
    main()
