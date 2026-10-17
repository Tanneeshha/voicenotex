# 🎓 VoiceNoteX — AI-Powered Lecture Note Assistant

> **University Final Year Project | Mobile AI System**
> Built with Flutter (Frontend) + FastAPI (Backend) + Groq LLM (GPT-OSS 20B) + Whisper STT (Groq)

---

## 📋 Table of Contents
1. [What is VoiceNoteX?](#what-is-voicenotex)
2. [System Architecture](#system-architecture)
3. [AI & Prompt Engineering](#ai--prompt-engineering)
4. [Classroom Intelligence Layer](#classroom-intelligence-layer)
5. [Features](#features)
6. [How to Run the Project](#how-to-run-the-project)
7. [API Endpoints](#api-endpoints)
8. [Cloud Services Used](#cloud-services-used)
9. [Expo/Viva Talking Points](#expovina-talking-points)

---

## What is VoiceNoteX?

VoiceNoteX is an AI-powered mobile application that helps university students automatically convert lecture recordings into structured, study-ready notes.

**The student workflow:**
1. Open the app → tap **Record**
2. Speak (or record the lecturer) — the app listens in real-time
3. Tap **Proceed** — the AI processes the transcript
4. Receive structured notes: topics, definitions, examples, exam questions
5. Rate the notes → optionally request AI improvement
6. Search, favorite, and revisit notes anytime

**The core idea:**
> Instead of students manually taking notes (and missing content), VoiceNoteX captures everything and uses AI to extract what matters academically.

---

## System Architecture

```
┌──────────────────────────────────────────┐
│           Flutter Mobile App             │
│                                          │
│  SpeechScreen → AudioService → Backend   │
│  HomeScreen   → ApiService  → Backend    │
│  AiScreen     → ApiService  → Backend    │
└─────────────────┬────────────────────────┘
                  │ HTTP/REST API
┌─────────────────▼────────────────────────┐
│         FastAPI Python Backend           │
│                                          │
│  /transcribe  → Groq Whisper v3          │
│  /chat        → Groq GPT-OSS 20B         │
│  /lectures    → MongoDB                  │
│  /feedback    → MongoDB                  │
│  /search      → MongoDB Text Search      │
└─────────────────┬────────────────────────┘
                  │
       ┌──────────┴──────────┐
       │                     │
┌──────▼──────┐    ┌─────────▼────────┐
│   Deepgram  │    │   Groq Cloud     │
│  Whisper v3 │    │  GPT-OSS 20B     │
│ (Audio→Text)│    │ (Text→Notes)     │
└─────────────┘    └──────────────────┘
```

**Data Flow:**
1. Student records audio → sent to **Deepgram** for transcription
2. Transcript sent to **Groq (GPT-OSS 20B)** with classroom-specific prompts
3. AI returns structured notes → saved in **MongoDB**
4. Flutter app displays notes → student provides feedback
5. Feedback stored → AI can regenerate improved notes

---

## AI & Prompt Engineering

### Why Prompt Engineering Matters

The AI model (OpenAI GPT-OSS 20B, hosted on Groq) is general-purpose — it doesn't know it's being used in a classroom context unless we tell it. **Prompt engineering** is the technique of writing detailed instructions to guide the AI's behavior.

In VoiceNoteX, prompts are:
- **Modular** — split into separate stages
- **Context-aware** — always tell the AI it's in a classroom
- **Structured** — the AI follows a template for consistent output

### The 3-Stage Prompt Pipeline (`backend/ai_engine/prompt_builder.py`)

```
Stage 1: UNDERSTANDING
"You are in a university classroom. The speaker is a lecturer.
 Identify: topic, level, main concepts."

       ↓

Stage 2: NOTES GENERATION
"Generate structured notes with:
 - Learning Objectives
 - Key Concepts (each with explanation)
 - Examples from the lecture
 - Key Definitions (glossary table)
 - Summary"

       ↓

Stage 3: STUDY ENHANCEMENT
"Add exam preparation:
 - 5 possible exam questions
 - Key terms to memorize
 - Revision checklist
 - 30-second quick recap"
```

**Why this is better than one big prompt:**
- Each stage has a clear purpose
- Easier to debug ("the notes are fine but the exam questions are wrong")
- Can be enabled/disabled independently
- Demonstrates professional software design

---

## Classroom Intelligence Layer

### What is it? (`backend/ai_engine/context_assumptions.py`)

This is the "smart assumptions" system. Instead of the AI trying to figure out what kind of content it's processing every time, we hardcode a set of assumptions:

| Assumption | Value |
|-----------|-------|
| Speaker role | University lecturer |
| Audience | University student |
| Content type | Academic lecture |
| Goal | Study and pass exams |
| Language | Formal academic English |

### Why this is important

Without this layer:
> AI might respond casually, miss academic structure, or treat the input as a general conversation.

With this layer:
> The AI always behaves like an academic study tool — ignoring filler speech, extracting definitions, and formatting notes for revision.

### Auto-Subject Detection

The system automatically detects the academic subject from the transcript:

```python
# If transcript contains: "algorithm, recursion, Big O, data structure"
detect_subject(transcript)  →  "Computer Science"

# If transcript contains: "DNA, cell, protein, evolution"
detect_subject(transcript)  →  "Biology"
```

This helps the AI use appropriate vocabulary and context for each subject.

---

## Features

| Feature | Description | Where |
|---------|-------------|-------|
| 🎙️ Live Recording | Record lecture audio in real-time | Speech Screen |
| 📝 AI Notes | 3-stage prompt pipeline generates structured notes | AI Screen |
| 🔍 Note Search | Search through all saved notes by keyword | Home Screen |
| ⭐ Favorites | Star important lectures for quick access | Home/Detail Screen |
| 👍 Feedback | Rate notes: Helpful / Needs Improvement | Detail Screen |
| 🔄 Auto-Improve | AI regenerates notes based on feedback type | Detail Screen |
| 📊 Stats Dashboard | See total lectures, favorites, AI notes count | Home Screen |
| 💬 AI Chat | Ask questions about any lecture | AI Screen |
| 🔐 Auth | Secure login with JWT tokens | Auth Screens |
| 📚 Subject Detection | Auto-detects academic subject | Backend (automatic) |
| 📄 PDF Export | Export notes as a PDF and view them in-app | Notes Screen |
| 📡 Nearby Share | Send notes to nearby devices without internet | Home Screen |
| 🎨 Note Style | Choose how notes are written (saved on device) | AI Screen / Onboarding |
| 🔑 Password Reset | Forgot-password and reset flow | Auth Screens |

---

## How to Run the Project

### Prerequisites
- Python 3.10+
- Flutter 3.x
- MongoDB (running locally)
- Android emulator or physical device

### Step 1: Set Up the Backend

```bash
# Navigate to the backend folder
cd backend

# Create a virtual environment
python -m venv venv

# Activate it
# Windows:
venv\Scripts\activate
# Mac/Linux:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Set up environment variables
cp .env.example .env
# Now edit .env and add your API keys
```

### Step 2: Get API Keys (FREE)

1. **Groq API Key** (for AI/LLM):
   - Go to: https://console.groq.com
   - Sign up → Create API Key → Copy it
   - Paste into `.env` as `GROQ_API_KEY=your_key`

2. **Deepgram API Key** (for audio transcription):
   - Go to: https://console.deepgram.com
   - Sign up → Create API Key → Copy it
   - Paste into `.env` as `DEEPGRAM_API_KEY=your_key`

### Step 3: Start MongoDB
```bash
# Windows (if MongoDB is installed):
net start MongoDB

# Mac/Linux:
sudo systemctl start mongod
```

### Step 4: Run the Backend
```bash
# From the backend/ folder:
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

You should see:
```
✅ MongoDB connected at mongodb://127.0.0.1:27017
✅ AI clients initialized successfully
INFO: Application startup complete.
INFO: Uvicorn running on http://0.0.0.0:8000
```

Visit http://localhost:8000/docs to see the API documentation.

### Step 5: Configure Flutter App

On Android, the app must know your computer's local IP address (the phone and PC must be on the same Wi-Fi).
You don't need to edit any code — pass the IP when running the app (see Step 6).

To find your IP:
- **Windows**: Run `ipconfig` → look for "IPv4 Address"
- **Mac/Linux**: Run `ifconfig` → look for `inet` under your network interface

### Step 6: Run the Flutter App
```bash
# From the root project folder:
flutter pub get

# Android device/emulator — replace with your PC's IP:
flutter run --dart-define=API_HOST=192.168.X.X

# Web / Windows / iOS simulator (backend on the same machine):
flutter run
```

---

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/signup` | Create account |
| POST | `/login` | Log in |
| POST | `/forgot-password` | Request a password reset |
| POST | `/reset-password` | Set a new password |
| GET | `/me` | Get the logged-in user |
| POST | `/chat` | Send message to AI |
| POST | `/new-chat` | Start a new chat session |
| GET | `/chats/{email}` | Get all chat sessions |
| GET | `/chat-history/{chat_id}` | Get messages of one chat |
| DELETE | `/chats/{email}` | Delete all chats of a user |
| DELETE | `/chat/{chat_id}` | Delete one chat |
| POST | `/transcribe` | Convert audio to text |
| POST | `/lectures` | Save a lecture |
| GET | `/lectures/{email}` | Get saved lectures |
| GET | `/lecture/{id}` | Get lecture details |
| DELETE | `/lecture/{id}` | Delete a lecture |
| PATCH | `/lecture/{id}/ai-response` | Update a lecture's AI notes |
| POST | `/feedback` | Submit note feedback |
| POST | `/improve-notes` | Regenerate improved notes |
| POST | `/favorite` | Toggle favorite |
| GET | `/search` | Search notes |
| GET | `/stats/{email}` | Get user statistics |
| GET | `/health` | Check system health |

---

## Cloud Services Used

| Service | Purpose | Why Chosen |
|---------|---------|------------|
| **Groq Cloud** | LLM inference (OpenAI GPT-OSS 20B, open-weight) | Free tier, very fast, OpenAI-compatible |
| **Groq Whisper** | Speech-to-text (whisper-large-v3) | High accuracy, handles accents and Urdu/English mixing |
| **MongoDB** | Database | Flexible schema, easy to use |

**Why Groq?**
Groq uses custom hardware (LPUs — Language Processing Units) that are much faster than traditional GPU-based AI. This means the notes appear in seconds, not minutes.

**Why Whisper on Groq?**
Whisper large-v3 is trained on speech in ~100 languages, so it handles accents and lectures that mix Urdu and English. Groq runs it in about a second per clip. (Deepgram's hosted Whisper was tested and took minutes per clip, so it is not used.)

---

## Expo/Viva Talking Points

### "What does your app do?"
> "VoiceNoteX is an AI-powered study assistant that converts lecture recordings into structured notes. The student records a lecture, the AI processes the audio through a 3-stage pipeline, and they get organized notes with exam questions — all automatically."

### "What AI techniques did you use?"
> "We used prompt engineering to build a modular pipeline. Instead of one generic prompt, we designed three specialized stages: understanding the lecture context, generating structured notes, and creating exam preparation material. We also built a Classroom Assumption Layer that pre-configures the AI's context for academic use."

### "How does the speech recognition work?"
> "We use Deepgram's Nova-2 model, which is accessed via a cloud API. The user's audio is sent to Deepgram, which returns a text transcript in seconds. This transcript is then passed to the GPT-OSS 20B language model via Groq's cloud API for note generation."

### "Why is your feedback system valuable?"
> "The feedback loop makes the system adaptive. When a student rates notes as 'Needs Improvement', they can specify what was wrong — too long, unclear, missing content. The AI then uses that specific feedback type to regenerate improved notes. This demonstrates a closed-loop AI system."

### "What was the most challenging part?"
> "Designing effective prompts. The AI needed to produce consistently formatted notes regardless of the lecture topic. We solved this by creating a prompt template with required sections, subject auto-detection, and filtering rules that remove filler speech."

### "How does your system handle different subjects?"
> "We built a subject detection algorithm that scans the transcript for domain-specific keywords. If it detects 'algorithm, recursion, Big O', it identifies the subject as Computer Science. The AI then uses this context to apply appropriate vocabulary and structure."

### "What makes this better than just using ChatGPT?"
> "Three things: First, it's designed specifically for classroom use — the AI never breaks context. Second, it integrates directly with audio recording — no manual copy-paste. Third, it has a feedback and improvement system — if notes aren't good, the AI tries again automatically."
