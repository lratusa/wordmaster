# Coqui TTS Server for WordMaster

Local text-to-speech server using [Coqui TTS](https://github.com/coqui-ai/TTS).

## Installation

```bash
# Create virtual environment (recommended)
python -m venv venv
venv\Scripts\activate  # Windows
# source venv/bin/activate  # Linux/Mac

# Install dependencies
pip install -r requirements.txt
```

## Usage

### Start the server
```bash
python start_server.py
```

The server runs on `http://localhost:5002`

### Test the API
```bash
# Generate speech
curl "http://localhost:5002/api/tts?text=Hello%20world" --output test.wav

# With language (for multilingual models)
curl "http://localhost:5002/api/tts?text=Hello&language-id=en" --output test.wav
```

## Available Models

### English (Fast)
```bash
set TTS_MODEL=tts_models/en/ljspeech/vits
python start_server.py
```

### Japanese
```bash
set TTS_MODEL=tts_models/ja/kokoro/tacotron2-DDC
python start_server.py
```

### Multilingual (XTTS v2 - Best Quality, Slower)
```bash
set TTS_MODEL=tts_models/multilingual/multi-dataset/xtts_v2
python start_server.py
```

XTTS v2 supports: English, Spanish, French, German, Italian, Portuguese, Polish, Turkish, Russian, Dutch, Czech, Arabic, Chinese, Japanese, Hungarian, Korean, Hindi

## List All Models
```bash
tts --list_models
```

## Docker Alternative
```bash
docker run -p 5002:5002 ghcr.io/coqui-ai/tts-cpu --model_name tts_models/en/ljspeech/vits
```
