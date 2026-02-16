# French CEFR Word List Generator

Generates complete French CEFR A1-C2 word lists with IPA phonetics, Chinese translations, and example sentences.

## Prerequisites

```bash
# Install dependencies
pip install google-generativeai jsonlines python-dotenv

# Set Gemini API key
export GEMINI_API_KEY="your-api-key-here"
# Or create a .env file:
echo "GEMINI_API_KEY=your-api-key-here" > .env
```

## Quick Start

```bash
# Navigate to generator directory
cd scripts/wordlist_generator

# Test with 10 words (A1 level)
python generate_french_cefr.py --level a1 --dry-run

# Generate A1 word list (500 words)
python generate_french_cefr.py --level a1

# Generate all levels (A1-C2, total 9500 words)
python generate_french_cefr.py --level all

# Resume from checkpoint if interrupted
python generate_french_cefr.py --level b1 --resume
```

## How It Works

### Step 1: Generate French Vocabulary
The script uses Gemini AI to generate appropriate French vocabulary for each CEFR level:
- **A1**: 500 words (basic everyday words: greetings, numbers, family, être/avoir/aller)
- **A2**: 1000 words (elementary daily situations: shopping, weather, hobbies)
- **B1**: 1500 words (intermediate familiar topics: work, travel, opinions)
- **B2**: 2000 words (upper-intermediate abstract topics: debates, complex grammar)
- **C1**: 2500 words (advanced sophisticated expression: academic, professional)
- **C2**: 3000 words (near-native: idioms, literary terms, specialized vocabulary)

### Step 2: Enrich with Details
For each French word, Gemini generates:
- **IPA Phonetics**: e.g., `[ɛtʁ]` for "être", `[fʁɑ̃sɛ]` for "français"
- **Chinese Translation**: e.g., "是；存在" for "être"
- **Example Sentences**: 2 sentences with Chinese translations
  ```json
  {
    "sentence": "Je suis étudiant.",
    "translation_cn": "我是学生。"
  }
  ```

### Step 3: UTF-8 Special Characters
The generator preserves all French diacritical marks:
- Accents: é, è, ê, ë (être, élève, fenêtre)
- Cedilla: ç (français, garçon)
- Ligature: œ (cœur, œuf)
- Other: ù (où), â (château)

## Output

Generated files are saved to:
```
assets/wordlists/french/
├── cefr_a1.json  (500 words)
├── cefr_a2.json  (1000 words)
├── cefr_b1.json  (1500 words)
├── cefr_b2.json  (2000 words)
├── cefr_c1.json  (2500 words)
└── cefr_c2.json  (3000 words)
```

### Output Format

```json
{
  "name": "CEFR A1 法语入门",
  "language": "fr",
  "description": "法语 A1 级别词汇（入门级） (500词)",
  "category": "cefr",
  "level": "A1",
  "words": [
    {
      "word": "être",
      "translation_cn": "是；存在",
      "phonetic": "[ɛtʁ]",
      "examples": [
        {
          "sentence": "Je suis étudiant.",
          "translation_cn": "我是学生。"
        },
        {
          "sentence": "Il est français.",
          "translation_cn": "他是法国人。"
        }
      ]
    }
  ]
}
```

## Checkpoints

Progress is saved to `checkpoints/french_cefr_*_progress.jsonl` after each batch.
If generation is interrupted, use `--resume` to continue from the checkpoint.

## Rate Limiting

- **Batch size**: 15 words per request
- **Rate limit**: 15 requests/minute (conservative for Gemini API)
- **Estimated time**:
  - A1 (500 words): ~35 batches, ~3-4 minutes
  - All levels (9500 words): ~633 batches, ~50-60 minutes

## Troubleshooting

### API Key Error
```
ValueError: Gemini API key not provided
```
**Solution**: Set `GEMINI_API_KEY` environment variable or create `.env` file

### Missing jsonlines Package
```
Warning: jsonlines not installed, cannot load checkpoint
```
**Solution**: `pip install jsonlines`

### UTF-8 Encoding Issues
The script uses `encoding='utf-8'` for all file operations. If you see garbled characters:
- Windows: Ensure terminal uses UTF-8 (`chcp 65001`)
- Linux/Mac: Should work by default

## Examples

### Generate A1 and A2 Only
```bash
python generate_french_cefr.py --level a1
python generate_french_cefr.py --level a2
```

### Test Before Full Generation
```bash
# Generate 10 words to test API and format
python generate_french_cefr.py --level a1 --dry-run
```

### Resume After Interruption
```bash
# If generation stops at batch 20/35
python generate_french_cefr.py --level a1 --resume
# Will skip first 19 batches (285 words) and continue from batch 20
```

## Next Steps

After generating word lists:
1. **Test UTF-8 Display**: Run app and check French tab shows special characters correctly
2. **Test TTS**: Download French TTS model and verify pronunciation
3. **Verify Examples**: Spot-check a few words for translation accuracy
4. **Generate DELF/DALF**: Create exam-specific lists (similar vocabulary, different focus)

## API Costs (Estimate)

- **Gemini 2.0 Flash**: Free tier includes 1500 requests/day
- **Total requests for all levels**: ~633 requests
- **Cost**: $0 (within free tier) ✓

## Support

If you encounter issues:
1. Check `checkpoints/` directory for progress files
2. Run with `--dry-run` to test with 10 words
3. Verify Gemini API key is valid
4. Check internet connection (API requires network access)
