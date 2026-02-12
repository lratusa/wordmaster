# Word List Generator

Scripts for generating comprehensive word lists with phonetics and example sentences.

## Setup

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Copy `.env.example` to `.env` and add your API key:
```bash
cp .env.example .env
# Edit .env and add your Gemini API key
```

3. Clone the source vocabulary data:
```bash
git clone https://github.com/KyleBing/english-vocabulary.git D:/temp/english-vocabulary
```

## Usage

### Generate CET-4 Word List

```bash
# Full generation (uses Gemini API for phonetics and examples)
python generate_cet4.py

# Dry run (test with 10 words)
python generate_cet4.py --dry-run

# Skip API, use only source data
python generate_cet4.py --no-api

# Start fresh (ignore checkpoint)
python generate_cet4.py --no-resume

# Custom paths
python generate_cet4.py --source /path/to/source.json --output /path/to/output.json
```

### Validate Word Lists

```bash
# Validate a specific file
python validate_wordlist.py path/to/wordlist.json

# Validate all wordlists in assets
python validate_wordlist.py --all
```

## File Structure

```
scripts/wordlist_generator/
├── README.md              # This file
├── requirements.txt       # Python dependencies
├── .env.example          # Template for API keys
├── .env                  # Actual API keys (gitignored)
├── generate_cet4.py      # Main CET-4 generation script
├── validate_wordlist.py  # Validation script
├── cet4_progress.jsonl   # Checkpoint file (gitignored)
└── utils/
    ├── __init__.py
    ├── gemini_client.py  # Gemini API wrapper
    └── json_repair.py    # JSON parsing utilities
```

## Output Format

Generated word lists follow this structure:

```json
{
  "name": "CET-4 大学英语四级",
  "language": "en",
  "description": "大学英语四级核心词汇 (约4500词)",
  "icon_name": "school",
  "words": [
    {
      "word": "abandon",
      "translation_cn": "放弃；抛弃",
      "part_of_speech": "vt.",
      "phonetic": "/əˈbændən/",
      "difficulty_level": 2,
      "examples": [
        {"sentence": "He abandoned his car in the snowstorm.", "translation_cn": "他在暴风雪中弃车了。"},
        {"sentence": "Don't abandon your dreams.", "translation_cn": "不要放弃你的梦想。"}
      ]
    }
  ]
}
```

## Cost Estimates

Using Gemini Flash API:
- ~4,500 words ÷ 15 per batch = ~300 requests
- ~500K tokens total
- Cost: ~$0.04 (Gemini Flash is $0.075/1M input tokens)

## Checkpoint & Resume

The script saves progress after each batch to `cet4_progress.jsonl`. If interrupted:
- Run again with same command to resume
- Use `--no-resume` to start fresh

## Data Sources

- **KyleBing/english-vocabulary**: Chinese translations, part of speech, phrases
- **Gemini Flash API**: IPA phonetics, example sentences with translations
