import os
from dotenv import load_dotenv
from deepgram import DeepgramClient
from openai import OpenAI

# ===== Load environment =====
load_dotenv(override=True)

# ===== AI Clients =====
GROQ_API_KEY = os.getenv("GROQ_API_KEY", "").strip()
DEEPGRAM_API_KEY = os.getenv("DEEPGRAM_API_KEY", "").strip()

# Speech-to-text model (Whisper hosted on Groq)
WHISPER_MODEL = os.getenv("WHISPER_MODEL", "whisper-large-v3")
TRANSCRIBE_TIMEOUT_SECONDS = 600

# JWT Secret — change this to a long random string in production
JWT_SECRET = os.getenv("JWT_SECRET", "voicenotex_super_secret_key_change_this_2024")
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_HOURS = 72  # 3 days

if not GROQ_API_KEY or not DEEPGRAM_API_KEY:
    print("WARNING: GROQ_API_KEY or DEEPGRAM_API_KEY not set in .env file")
    print("  Create a .env file in the backend/ folder with:")
    print("    GROQ_API_KEY=your_groq_key_here")
    print("    DEEPGRAM_API_KEY=your_deepgram_key_here")
    deepgram_client = None
    groq_client = None
else:
    try:
        deepgram_client = DeepgramClient(api_key=DEEPGRAM_API_KEY)
        groq_client = OpenAI(
            api_key=GROQ_API_KEY,
            base_url="https://api.groq.com/openai/v1"
        )
        print("[OK] AI clients initialized successfully")
    except Exception as e:
        print(f"ERROR initializing AI clients: {e}")
        deepgram_client = None
        groq_client = None
