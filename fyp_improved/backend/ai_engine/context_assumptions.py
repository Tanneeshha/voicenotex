"""
context_assumptions.py
=======================
Classroom Assumption Layer for VoiceNoteX

This module defines what the AI system automatically "knows" about
every piece of audio or text it processes.

Think of it like telling the AI:
  "Hey — you are always in a university classroom.
   The person speaking is always a lecturer.
   The person reading is always a student."

This means the AI doesn't have to guess the context every time.
It already knows, so its answers are smarter and more focused.
"""

# ============================================================
# CLASSROOM CONTEXT — What the AI always assumes
# ============================================================

CLASSROOM_CONTEXT = {
    # Who is speaking in the audio/transcript
    "speaker_role": "university lecturer",

    # Who is reading and using the notes
    "audience_role": "university student",

    # What kind of content this is
    "content_type": "academic lecture",

    # What environment this is from
    "setting": "university classroom or lecture hall",

    # What the student wants to do with the output
    "student_goal": "study, revise, and prepare for exams",

    # Language preference
    "language": "formal academic English",

    # How detailed should the notes be
    "detail_level": "comprehensive but readable",
}


# ============================================================
# CONTENT FILTERS — What to IGNORE vs EXTRACT
# ============================================================

# Words/phrases that are casual filler speech — the AI should ignore these
IGNORE_PATTERNS = [
    "um", "uh", "like", "you know", "right?",
    "okay so", "alright", "basically", "kind of",
    "let me just", "so yeah", "moving on",
    "can everyone hear me", "is the mic working",
    "sorry about that", "where was I",
]

# Keywords that signal IMPORTANT academic content — extract these
EXTRACT_SIGNALS = {
    "definition": [
        "is defined as", "means", "refers to", "is called",
        "by definition", "in other words", "that is",
    ],
    "example": [
        "for example", "for instance", "such as", "consider",
        "take the case of", "as an illustration", "e.g.",
    ],
    "key_concept": [
        "importantly", "key point", "remember", "note that",
        "this is crucial", "fundamentally", "the main idea",
        "the primary", "essentially", "the core concept",
    ],
    "exam_hint": [
        "this will be on the exam", "you need to know",
        "this is important", "make sure you understand",
        "exam question", "test question", "assignment",
    ],
    "formula_law": [
        "formula", "equation", "law", "theorem", "rule",
        "principle", "postulate", "axiom",
    ],
}


# ============================================================
# ACADEMIC SUBJECTS — Auto-detection signals
# ============================================================

SUBJECT_SIGNALS = {
    "Computer Science": [
        "algorithm", "data structure", "complexity", "Big O",
        "recursion", "database", "network", "API", "class",
        "object", "function", "loop", "variable", "compiler",
    ],
    "Mathematics": [
        "theorem", "proof", "equation", "matrix", "vector",
        "calculus", "integral", "derivative", "function",
        "set theory", "probability", "statistics",
    ],
    "Physics": [
        "velocity", "acceleration", "force", "energy",
        "quantum", "relativity", "momentum", "wave",
        "particle", "electric field", "magnetic",
    ],
    "Biology": [
        "cell", "DNA", "protein", "organism", "evolution",
        "photosynthesis", "enzyme", "chromosome", "gene",
        "mitosis", "ecosystem", "species",
    ],
    "Economics": [
        "supply", "demand", "market", "inflation", "GDP",
        "fiscal", "monetary", "elasticity", "marginal",
        "utility", "equilibrium", "scarcity",
    ],
    "Engineering": [
        "circuit", "voltage", "current", "resistance",
        "mechanical", "thermodynamics", "stress", "strain",
        "structural", "load", "torque", "frequency",
    ],
}


def detect_subject(transcript: str) -> str:
    """
    Looks at a transcript and guesses which university subject it belongs to.

    Example:
        detect_subject("Today we study DNA and cell division...")
        → "Biology"

    Parameters:
        transcript (str): The raw lecture text

    Returns:
        str: The detected subject name, or "Academic" if unknown
    """
    transcript_lower = transcript.lower()
    scores = {}

    for subject, keywords in SUBJECT_SIGNALS.items():
        # Count how many subject keywords appear in the transcript
        score = sum(1 for kw in keywords if kw.lower() in transcript_lower)
        if score > 0:
            scores[subject] = score

    if not scores:
        return "Academic"

    # Return the subject with the most keyword matches
    return max(scores, key=scores.get)


def get_classroom_assumptions() -> dict:
    """
    Returns all classroom assumptions as a single dictionary.
    This is used by the prompt builder to inject context.

    Returns:
        dict: All classroom context assumptions
    """
    return CLASSROOM_CONTEXT.copy()


def get_ignore_patterns() -> list:
    """
    Returns the list of filler phrases the AI should ignore.

    Returns:
        list: Casual speech patterns to filter
    """
    return IGNORE_PATTERNS.copy()


def get_extract_signals() -> dict:
    """
    Returns the keyword signals for extracting academic content.

    Returns:
        dict: Category → list of signal phrases
    """
    return EXTRACT_SIGNALS.copy()
