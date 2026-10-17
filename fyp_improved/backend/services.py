"""
services.py
===========
Core AI Service Layer for VoiceNoteX

This file contains all the functions that talk to the AI and audio APIs.
It is the "brain" of the backend.

WHAT CHANGED (improvements):
- Now uses the ai_engine.prompt_builder for smart, structured prompts
- Lecture transcripts go through the FULL 3-stage pipeline
- Regular chat still works with smart style detection
- Added feedback improvement function
- Better error handling and logging
"""

import re
import logging
from typing import Optional, List, Tuple, Dict, Any

from config import groq_client, WHISPER_MODEL, TRANSCRIBE_TIMEOUT_SECONDS

# Import Classroom Intelligence Layer
from ai_engine.prompt_builder import (
    build_full_lecture_prompt,
    build_feedback_improvement_prompt,
    build_title_prompt,
    AI_IDENTITY,
)
from ai_engine.context_assumptions import detect_subject

logger = logging.getLogger("voicenotex.services")

# ============================================================
# STYLE PROMPTS — used for regular (non-lecture) chat
# ============================================================

STYLE_PROMPTS = {
    "short":        "Provide a concise answer in 1–2 sentences.",
    "descriptive":  "Explain clearly with examples in 1–3 paragraphs.",
    "long":         "Provide a detailed explanation with multiple structured paragraphs.",
    "professional": "Provide a formal, professional explanation suitable for academic use.",
    "bulletpoints": "Present the information using clear bullet points.",
}

# ============================================================
# GENERAL SYSTEM PROMPT — used for regular chat (non-lecture)
# ============================================================

GLOBAL_SYSTEM_PROMPT = f"""{AI_IDENTITY}

You are in general assistant mode (not processing a lecture transcript).
Help the student with academic questions, concept explanations, and study support.
Always respond in clear, academic English with proper structure."""


# ============================================================
# DETECT IF INPUT IS A LECTURE TRANSCRIPT
# ============================================================

def is_lecture_transcript(text: str) -> bool:
    """
    Determines whether the input text looks like a lecture transcript.

    A lecture transcript is:
    - Long (more than 150 words)
    - Not a question (few question marks)

    This tells the AI which mode to use:
    - True  → use the 3-stage lecture pipeline
    - False → use regular chat mode

    Parameters:
        text (str): The user's input

    Returns:
        bool: True if this looks like a lecture transcript
    """
    text = text.strip()
    word_count = len(text.split())
    question_count = text.count("?")
    # Long text with very few questions = likely a lecture transcript
    return word_count > 150 and question_count <= 2


# ============================================================
# MAIN CHAT FUNCTION
# ============================================================

def _parse_personalization(msg: str) -> dict:
    """Extracts personalization settings (student_level, language, focus_areas, etc.) from system prompt text."""
    prefs = {
        "student_level": "Intermediate",
        "explanation_style": "Balanced",
        "note_length": "Balanced length",
        "focus_areas": [],
        "note_format": "Headings & Bullets",
        "language": "English",
    }
    if not msg:
        return prefs

    # Student Level (Advanced Level)
    m_level = re.search(r'(?:Advanced Level|Student Level):\s*([A-Za-z]+)', msg, re.IGNORECASE)
    if m_level:
        prefs["student_level"] = m_level.group(1).capitalize()

    # Output Language
    m_lang = re.search(r'Language:\s*([^.\n]+)', msg, re.IGNORECASE)
    if m_lang:
        prefs["language"] = m_lang.group(1).strip()

    # Focus Areas
    m_focus = re.search(r'Focus Areas:\s*([^.\n]+)', msg, re.IGNORECASE)
    if m_focus:
        prefs["focus_areas"] = [x.strip() for x in m_focus.group(1).split(",")]

    # Note Length
    m_len = re.search(r'Note Length:\s*([^.\n]+)', msg, re.IGNORECASE)
    if m_len:
        prefs["note_length"] = m_len.group(1).strip()

    # Note Format
    m_fmt = re.search(r'Note Format:\s*([^.\n]+)', msg, re.IGNORECASE)
    if m_fmt:
        prefs["note_format"] = m_fmt.group(1).strip()

    return prefs


def chat_with_llm(
    user_message: str,
    styles: Optional[List[str]] = None,
    code_request: bool = False,
    only_code: bool = False,
    language: Optional[str] = None,
    history: Optional[List[Dict[str, Any]]] = None
) -> Tuple[str, List[Dict[str, Any]]]:
    """
    Sends a message to the AI and gets a response.

    This function automatically detects whether the input is a lecture transcript
    and applies student level personalization rules.
    """
    if not groq_client:
        raise RuntimeError("Groq client is not configured. Check your GROQ_API_KEY in .env")
    assert groq_client is not None  # narrows type for linter

    # --- Build message history & extract system personalization ---
    messages: List[Dict[str, Any]] = list(history) if history else []
    styles = styles or []

    incoming_system_msg = ""
    if messages and messages[0].get("role") == "system":
        incoming_system_msg = messages.pop(0).get("content", "")

    prefs = _parse_personalization(incoming_system_msg)

    # --- CHOOSE SYSTEM PROMPT based on content type ---
    if is_lecture_transcript(user_message) and not history:
        # Use personalized 3-stage Classroom Intelligence Pipeline
        system_content = build_full_lecture_prompt(
            transcript=user_message,
            student_level=prefs["student_level"],
            focus_areas=prefs["focus_areas"],
            language=prefs["language"],
            note_length=prefs["note_length"],
            note_format=prefs["note_format"],
        )
        logger.info(
            f"[LECTURE MODE] Detected transcript ({len(user_message.split())} words), "
            f"subject: {detect_subject(user_message)}, student_level: {prefs['student_level']}"
        )
    else:
        # Regular chat mode with style and student-level awareness
        style_instruction = " ".join(
            [STYLE_PROMPTS[s] for s in styles if s in STYLE_PROMPTS]
        )
        system_content = GLOBAL_SYSTEM_PROMPT
        if style_instruction:
            system_content += f"\n\nRESPONSE STYLE: {style_instruction}"

    final_system_content = system_content
    if incoming_system_msg:
        final_system_content = f"{system_content}\n\nUSER PERSONALIZATION & STUDENT LEVEL SETTINGS:\n{incoming_system_msg}"

    messages.insert(0, {"role": "system", "content": final_system_content})

    # --- Handle code requests ---
    prompt = user_message
    if code_request:
        lang = language or "the most appropriate language"
        prompt += f"\n\nPlease generate executable {lang} code."
        if only_code:
            prompt += " Return ONLY the code with no explanation or preamble."

    messages.append({"role": "user", "content": prompt})

    try:
        # pyrefly: ignore [no-matching-overload]
        response = groq_client.chat.completions.create(
            model="openai/gpt-oss-20b",
            messages=messages,
            max_tokens=4000,
            temperature=0.7,
        )
        assistant_reply = response.choices[0].message.content
        messages.append({"role": "assistant", "content": assistant_reply})
        return assistant_reply, messages

    except Exception as e:
        logger.error(f"Groq API error: {e}")
        raise RuntimeError(f"AI service error: {str(e)}")


# ============================================================
# PROCESS LECTURE (dedicated function for lecture processing)
# ============================================================

def process_lecture_transcript(transcript: str, style: str = "standard") -> str:
    """
    Dedicated function for processing lecture transcripts.

    This runs through the full 3-stage pipeline:
    1. Understand the lecture
    2. Generate structured notes
    3. Add exam preparation material

    Parameters:
        transcript (str): The raw lecture transcript
        style (str): Notes style (standard, detailed, concise, visual)

    Returns:
        str: Fully formatted lecture notes with study enhancement
    """
    if not groq_client:
        raise RuntimeError("Groq client is not configured. Check your GROQ_API_KEY in .env")
    assert groq_client is not None  # narrows type for linter

    system_prompt = build_full_lecture_prompt(transcript, style)
    subject = detect_subject(transcript)
    logger.info(f"[LECTURE PROCESSING] Subject: {subject}, Words: {len(transcript.split())}")

    try:
        response = groq_client.chat.completions.create(
            model="openai/gpt-oss-20b",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": f"Process this lecture transcript:\n\n{transcript}"},
            ],
            max_tokens=4000,
            temperature=0.6,  # Slightly lower = more consistent academic output
        )
        # pyrefly: ignore [bad-return]
        return response.choices[0].message.content

    except Exception as e:
        logger.error(f"Lecture processing error: {e}")
        raise RuntimeError(f"Failed to process lecture: {str(e)}")


# ============================================================
# IMPROVE NOTES BASED ON FEEDBACK
# ============================================================

def improve_notes_from_feedback(original_notes: str, feedback_type: str) -> str:
    """
    When a student rates notes as 'Needs Improvement', the AI
    automatically regenerates improved notes.

    Parameters:
        original_notes (str): The notes that were poorly rated
        feedback_type (str): What was wrong (too_long, unclear, etc.)

    Returns:
        str: Improved version of the notes
    """
    if not groq_client:
        raise RuntimeError("Groq client is not configured.")
    assert groq_client is not None  # narrows type for linter

    system_prompt = build_feedback_improvement_prompt(original_notes, feedback_type)

    try:
        response = groq_client.chat.completions.create(
            model="openai/gpt-oss-20b",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": "Please improve these lecture notes based on the feedback."},
            ],
            max_tokens=3000,
            temperature=0.6,
        )
        # pyrefly: ignore [bad-return]
        return response.choices[0].message.content

    except Exception as e:
        logger.error(f"Notes improvement error: {e}")
        raise RuntimeError(f"Failed to improve notes: {str(e)}")


# ============================================================
# CHAT TITLE GENERATOR
# ============================================================

def generate_chat_title(first_prompt: str) -> str:
    """
    Automatically generates a short, smart title for a chat or lecture.

    Example:
        Input: "Today we study database normalization and the three normal forms..."
        Output: "Database Normalization Normal Forms"

    Parameters:
        first_prompt (str): The first message or transcript content

    Returns:
        str: A short 2–6 word title
    """
    if not groq_client:
        return first_prompt[:25] if first_prompt else "New Chat"
    assert groq_client is not None  # narrows type for linter

    try:
        response = groq_client.chat.completions.create(
            model="openai/gpt-oss-20b",
            messages=[
                {"role": "system", "content": build_title_prompt()},
                {"role": "user", "content": f"Generate a title for: {first_prompt[:300]}"},
            ],
            max_tokens=15,
            temperature=0.4,
        )
        # pyrefly: ignore [missing-attribute]
        title = response.choices[0].message.content.strip()
        title = re.sub(r'["\'.\n]', '', title).strip()
        return title if title else first_prompt[:25]

    except Exception as e:
        logger.warning(f"Title generation failed: {e}")
        return first_prompt[:25] if first_prompt else "Chat"


# ============================================================
# STYLE DETECTION — auto-detect from message
# ============================================================

def detect_style(text: str) -> list:
    """
    Automatically detects what response style is best for this message.

    Examples:
        "What is DNA?" → short (simple question)
        "Explain machine learning algorithms in detail" → long
        "List the main types of databases" → bulletpoints

    Parameters:
        text (str): The user's message

    Returns:
        list: List of style names (matches STYLE_PROMPTS keys)
    """
    text_lower = text.lower()

    if len(text_lower.split()) > 150:
        return ["long"]      # long transcript → detailed response
    if any(w in text_lower for w in ["explain", "why", "how does", "what is", "describe"]):
        return ["descriptive"]
    if any(w in text_lower for w in ["detail", "elaborate", "thoroughly", "in depth"]):
        return ["long"]
    if any(w in text_lower for w in ["report", "formal", "professional", "academic"]):
        return ["professional"]
    if any(w in text_lower for w in ["list", "bullet", "points", "enumerate"]):
        return ["bulletpoints"]
    if len(text_lower.split()) < 15:
        return ["short"]

    return ["descriptive"]


# ============================================================
# CODE REQUEST DETECTION
# ============================================================

def auto_detect_code_request(user_input: str):
    """
    Detects if the user is asking for code.

    Parameters:
        user_input (str): The user's message

    Returns:
        tuple: (code_request bool, only_code bool)
    """
    code_keywords = [
        "code", "function", "program", "script",
        "implementation", "algorithm", "class", "method"
    ]
    only_code_keywords = ["only code", "just code", "code only", "no explanation"]

    code_request = any(word in user_input.lower() for word in code_keywords)
    only_code = any(word in user_input.lower() for word in only_code_keywords)
    return code_request, only_code


# ============================================================
# HISTORY MANAGEMENT
# ============================================================

MAX_HISTORY = 20

def trim_history(history: Optional[List[Dict[str, Any]]]) -> List[Dict[str, Any]]:
    """
    Keeps history manageable to avoid AI token overflow.

    Keeps the system message plus the last MAX_HISTORY messages.

    Parameters:
        history (list): Full message history

    Returns:
        list: Trimmed history
    """
    if not history:
        return []

    system_msgs = [m for m in history if m.get("role") == "system"]
    non_system = [m for m in history if m.get("role") != "system"]

    if len(non_system) > MAX_HISTORY:
        non_system = non_system[-MAX_HISTORY:]

    return system_msgs + non_system


# ============================================================
# AUDIO TRANSCRIPTION (Groq Whisper)
# ============================================================

def transcribe_file_bytes(file_bytes: bytes, filename: str = "lecture.m4a") -> str:
    """
    Converts an audio file (bytes) into text using Whisper (large-v3) hosted on Groq.

    This is how lecture audio gets turned into text that the AI can process.
    Whisper handles accents and mixed Urdu/English speech, and Groq runs it fast.

    Parameters:
        file_bytes (bytes): Raw audio file data
        filename (str): Original file name — Groq uses the extension to detect the format

    Returns:
        str: The transcribed text
    """
    if not groq_client:
        raise RuntimeError("Groq client is not configured. Check your GROQ_API_KEY in .env")

    try:
        response = groq_client.audio.transcriptions.create(
            model=WHISPER_MODEL,
            file=(filename, file_bytes),
            timeout=TRANSCRIBE_TIMEOUT_SECONDS,
        )
        return response.text.strip()

    except Exception as e:
        logger.error(f"Whisper transcription error: {e}")
        raise RuntimeError(f"Transcription failed: {str(e)}")
