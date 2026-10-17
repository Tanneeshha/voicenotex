"""
prompt_builder.py
=================
Advanced Prompt Engineering Pipeline for VoiceNoteX

This module builds smart, structured prompts for the AI.

Instead of one big hardcoded prompt, we have a PIPELINE of 3 stages:
  Stage 1 → Understand what the lecture is about
  Stage 2 → Generate structured, study-ready notes
  Stage 3 → Create exam prep material (questions, key terms, revision)

Why this matters for your Viva/Expo:
  You can explain: "We use prompt engineering to guide the AI through
  three stages of academic processing — just like how a human student
  would first understand, then take notes, then prepare for an exam."
"""

from typing import Optional, List

try:
    from ai_engine.context_assumptions import (
        get_classroom_assumptions,
        get_ignore_patterns,
        detect_subject,
    )
except ImportError:
    from .context_assumptions import (
        get_classroom_assumptions,
        get_ignore_patterns,
        detect_subject,
    )


# ============================================================
# BASE SYSTEM IDENTITY — Who the AI thinks it is
# ============================================================

AI_IDENTITY = """You are VoiceNoteX, an intelligent AI study assistant embedded in a university classroom.

Your job is to help students by converting raw lecture content into structured, academic, study-ready notes.

YOU ALWAYS ASSUME:
- The input comes from a university lecture recording or transcript
- The speaker is a university lecturer or professor
- The student needs clear, organized notes to study and revise
- All content is academic and should be treated seriously

YOUR CORE RULES:
- Always write in clear, formal academic English
- Never include filler words (um, uh, like, you know)
- Always organize information with proper headings and structure
- Be concise but comprehensive — students need quality, not quantity
- If content is unclear or inaudible, note it gracefully, do not guess
- Never make up facts or add information not present in the transcript"""


# ============================================================
# STAGE 1: LECTURE UNDERSTANDING PROMPT
# Detects topic, extracts context, sets the stage
# ============================================================

def build_understanding_prompt(transcript: str) -> str:
    """
    Stage 1: Understanding the Lecture

    Before generating notes, the AI first understands:
      - What subject is this?
      - What is the main topic?
      - What academic level is this?

    This is like a student reading the chapter title before diving in.

    Parameters:
        transcript (str): Raw lecture transcript

    Returns:
        str: The Stage 1 system prompt
    """
    subject = detect_subject(transcript)
    assumptions = get_classroom_assumptions()
    ignore = ", ".join(get_ignore_patterns()[:8])  # show first 8 examples

    return f"""{AI_IDENTITY}

--- STAGE 1: LECTURE UNDERSTANDING ---

DETECTED SUBJECT AREA: {subject}
SPEAKER ROLE: {assumptions['speaker_role']}
AUDIENCE: {assumptions['audience_role']}
SETTING: {assumptions['setting']}

YOUR TASK IN THIS STAGE:
Analyze the lecture transcript and identify:
1. The specific topic or module being taught
2. The academic level (introductory, intermediate, advanced)
3. The 3–5 most important concepts the lecturer covered
4. Any definitions, examples, or exam hints present

FILTERING RULE:
Ignore casual filler speech such as: {ignore}
Focus only on academic content that helps a student learn.

OUTPUT FORMAT:
Respond with a brief analysis before generating notes.
Include: Topic, Academic Level, Main Concepts (as a list)"""


# ============================================================
# STAGE 2: NOTES GENERATION PROMPT
# The main output — structured lecture notes
# ============================================================

def build_notes_prompt(transcript: str, style: str = "standard") -> str:
    """
    Stage 2: Generating Structured Lecture Notes

    This is the main stage — it produces the actual study notes.
    Notes are organized in sections just like a professional textbook.

    Parameters:
        transcript (str): Raw lecture transcript
        style (str): "standard", "detailed", "concise", or "visual"

    Returns:
        str: The Stage 2 system prompt for notes generation
    """
    subject = detect_subject(transcript)
    assumptions = get_classroom_assumptions()

    # Style-specific instructions
    style_instructions = {
        "standard": "Use clear headings, bullet points, and short explanations.",
        "detailed": "Write full explanations for each concept with examples and context.",
        "concise": "Use bullet points only. Keep each point to one line maximum.",
        "visual": "Use tables, structured lists, and visual hierarchy. Great for revision.",
    }

    style_guide = style_instructions.get(style, style_instructions["standard"])

    return f"""{AI_IDENTITY}

--- STAGE 2: NOTES GENERATION ---

SUBJECT: {subject}
STUDENT GOAL: {assumptions['student_goal']}
NOTES STYLE: {style.upper()} — {style_guide}

YOUR TASK:
Convert the lecture transcript into professional, study-ready notes.

REQUIRED STRUCTURE — use this exact format:

## 📚 Lecture Topic
[One clear sentence describing what this lecture covers]

## 🎯 Learning Objectives
[What the student should understand after this lecture — 3–5 bullet points]

## 📖 Key Concepts
[The main ideas from the lecture — each as a sub-heading with explanation]

### [Concept Name]
[Clear explanation in 2–4 sentences. Include any definition the lecturer gave.]

### [Concept Name]
[Continue for each major concept...]

## 💡 Examples & Case Studies
[Any examples the lecturer mentioned, clearly labeled]

## 🔑 Key Definitions
[A glossary of important terms used in this lecture]
| Term | Definition |
|------|-----------|
| [term] | [definition] |

## 📝 Summary
[A 3–4 sentence summary of the entire lecture. What are the main takeaways?]

IMPORTANT RULES:
- Use ONLY information from the transcript
- Remove filler words and stutters
- Correct obvious transcription errors (e.g., wrong homophones)
- If a section has no content, write "Not covered in this lecture"
- Format all definitions as: **[Term]** — [definition]"""


# ============================================================
# STAGE 3: STUDY ENHANCEMENT PROMPT
# Exam questions, key terms, revision checklist
# ============================================================

def build_study_enhancement_prompt(transcript: str) -> str:
    """
    Stage 3: Study Enhancement

    After notes are generated, this stage creates extra revision material:
      - Possible exam questions
      - Key terms to memorize
      - A self-check revision list
      - A one-paragraph "quick recap"

    This is the feature that makes VoiceNoteX go beyond a basic transcriber.

    Parameters:
        transcript (str): Raw lecture transcript

    Returns:
        str: The Stage 3 system prompt
    """
    subject = detect_subject(transcript)

    return f"""{AI_IDENTITY}

--- STAGE 3: STUDY ENHANCEMENT ---

SUBJECT: {subject}

YOUR TASK:
After the lecture notes, generate exam preparation material.

REQUIRED OUTPUT:

## 🎓 Possible Exam Questions
[Generate 5 realistic exam questions based on this lecture content.
Mix question types: multiple choice hints, short answer, and essay.]

1. [Question 1 — factual recall]
2. [Question 2 — definition/explanation]
3. [Question 3 — application/example]
4. [Question 4 — comparison or analysis]
5. [Question 5 — broader conceptual understanding]

## 📋 Key Terms to Memorize
[List the most important terms a student must know for an exam]
- **[Term]**: [one-line definition]
- **[Term]**: [one-line definition]
(Aim for 5–10 terms)

## ✅ Revision Checklist
[A self-assessment list. Student should tick each when they understand it.]
- [ ] I can explain [concept 1]
- [ ] I understand the difference between [A] and [B]
- [ ] I can give an example of [concept]
(Generate 5–7 checklist items)

## ⚡ Quick Recap (30-second summary)
[One paragraph. If a student has 30 seconds before an exam, what must they know?]

TONE: Encouraging and academic. This is for a student who is preparing seriously."""


# ============================================================
# FEEDBACK ANALYSIS PROMPT
# Used when student says notes were "not helpful"
# ============================================================

def build_feedback_improvement_prompt(original_notes: str, feedback_type: str) -> str:
    """
    When a student marks notes as 'Needs Improvement', the AI
    automatically tries to improve them.

    Parameters:
        original_notes (str): The AI-generated notes that were rated poorly
        feedback_type (str): "too_long", "too_short", "unclear", "missing_content"

    Returns:
        str: A prompt asking the AI to improve the notes
    """
    improvement_instructions = {
        "too_long": "The notes are too long. Summarize them. Keep only the most essential points. Aim for 50% shorter.",
        "too_short": "The notes are too brief. Expand on each concept with more explanation and examples.",
        "unclear": "The notes are confusing. Rewrite them in simpler language. Use shorter sentences and clearer structure.",
        "missing_content": "Important content seems to be missing. Re-analyze and add any overlooked concepts.",
        "general": "Improve the quality, clarity, and organization of these notes.",
    }

    instruction = improvement_instructions.get(feedback_type, improvement_instructions["general"])

    return f"""{AI_IDENTITY}

--- FEEDBACK IMPROVEMENT MODE ---

A student has rated these lecture notes as needing improvement.
Feedback type: {feedback_type.upper()}

IMPROVEMENT INSTRUCTION: {instruction}

ORIGINAL NOTES:
{original_notes[:2000]}...

YOUR TASK:
Rewrite the notes according to the feedback instruction above.
Keep the same structure (headings, sections) but improve the content quality.
Output the improved version of the complete notes."""


# ============================================================
# TITLE GENERATION PROMPT
# Auto-generates a good lecture title from the content
# ============================================================

def build_title_prompt() -> str:
    """
    Builds the system prompt for auto-generating lecture titles.

    Returns:
        str: A short, focused prompt for title generation
    """
    return """You are a university lecture title generator.

Given a lecture transcript or notes, generate a clear, professional lecture title.

RULES:
- Maximum 6 words
- Use academic language
- Format like a textbook chapter title (Title Case)
- Do NOT include quotes, punctuation at the end, or numbers
- Examples of good titles:
    Introduction to Machine Learning
    Database Normalization and Design
    Principles of Organic Chemistry
    Economic Supply and Demand Theory

Output ONLY the title. Nothing else."""


# ============================================================
# PERSONALIZATION HELPERS — Student Level & Preferences
# ============================================================

def get_student_level_directive(level: str = "Intermediate") -> str:
    """Returns detailed AI prompt rules based on the student's academic level."""
    level_clean = (level or "Intermediate").strip().capitalize()
    
    if "Beginner" in level_clean:
        return (
            "TARGET AUDIENCE: BEGINNER / INTRODUCTORY STUDENT.\n"
            "- Use accessible, intuitive explanations and relatable real-world analogies.\n"
            "- Break down complex academic terms into plain language.\n"
            "- Provide step-by-step logic before introducing formal concepts.\n"
            "- Avoid overly dense theoretical jargon without explaining it first."
        )
    elif "Advanced" in level_clean:
        return (
            "TARGET AUDIENCE: ADVANCED / GRADUATE STUDENT.\n"
            "- Provide deep analytical and theoretical depth.\n"
            "- Use formal mathematical/technical notation, architectural design principles, and trade-off evaluations.\n"
            "- Include edge cases, underlying mechanics, and higher-level conceptual connections."
        )
    elif "Expert" in level_clean:
        return (
            "TARGET AUDIENCE: EXPERT / PHD / PROFESSIONAL.\n"
            "- Provide high-density, peer-review-grade synthesis.\n"
            "- Use rigorous domain vocabulary, mathematical formulations, and concise structural summaries.\n"
            "- Skip introductory fluff; focus directly on technical mechanics, methodologies, and synthesis."
        )
    else:  # Intermediate / Default
        return (
            "TARGET AUDIENCE: INTERMEDIATE / UNDERGRADUATE STUDENT.\n"
            "- Provide balanced academic rigor with clear textbook-quality explanations.\n"
            "- Include standard formal definitions, key concepts, and structured bullet points.\n"
            "- Provide practical examples alongside theoretical ideas."
        )


def get_language_directive(language: str = "English") -> str:
    """Returns AI prompt instructions for the output language preference."""
    lang_clean = (language or "English").strip().lower()
    
    if "urdu + english" in lang_clean or "roman" in lang_clean:
        return "OUTPUT LANGUAGE: Roman Urdu + English bilingual format (explain concepts in easy Roman Urdu using English technical terms)."
    elif "urdu" in lang_clean:
        return "OUTPUT LANGUAGE: Formal Urdu language using proper Urdu script."
    elif "same" in lang_clean:
        return "OUTPUT LANGUAGE: Detect and match the primary language used in the lecture transcript."
    else:
        return "OUTPUT LANGUAGE: Clear, formal academic English."


def get_focus_areas_directive(focus_areas: Optional[List[str]] = None) -> str:
    """Returns focus area guidelines based on user selected priorities."""
    if not focus_areas:
        return ""
    
    directives = []
    for area in focus_areas:
        a = area.lower()
        if "formula" in a:
            directives.append("- Add a dedicated '📐 Mathematical & Technical Formulas' section for equations/code.")
        if "definition" in a:
            directives.append("- Expand the '🔑 Key Definitions' table with comprehensive terms.")
        if "exam" in a:
            directives.append("- Highlight potential exam hints with '⚠️ EXAM TIP:' callouts.")
        if "example" in a:
            directives.append("- Expand '💡 Examples & Case Studies' with detailed step-by-step walk-throughs.")
        if "difficult" in a:
            directives.append("- Include a '🧠 Deep Dive into Challenging Concepts' section.")
    if directives:
        return "SPECIAL FOCUS INSTRUCTIONS:\n" + "\n".join(directives)
    return ""


# ============================================================
# FULL PIPELINE — Combines all stages into one prompt
# Used for the main lecture processing endpoint
# ============================================================

def build_full_lecture_prompt(
    transcript: str,
    style: str = "standard",
    student_level: str = "Intermediate",
    focus_areas: Optional[List[str]] = None,
    language: str = "English",
    note_length: str = "Balanced length",
    note_format: str = "Headings & Bullets",
) -> str:
    """
    The COMPLETE prompt pipeline — all 3 stages in one, fully personalized to student level.
    """
    subject = detect_subject(transcript)
    assumptions = get_classroom_assumptions()
    level_directive = get_student_level_directive(student_level)
    language_directive = get_language_directive(language)
    focus_directive = get_focus_areas_directive(focus_areas)

    return f"""{AI_IDENTITY}

========================================
FULL LECTURE PROCESSING PIPELINE (PERSONALIZED)
========================================

DETECTED CONTEXT:
- Subject: {subject}
- Speaker: {assumptions['speaker_role']}
- Audience: {assumptions['audience_role']}
- Goal: {assumptions['student_goal']}

PERSONALIZATION DIRECTIVES:
{level_directive}
{language_directive}
- NOTE LENGTH PREFERENCE: {note_length}
- NOTE FORMAT PREFERENCE: {note_format}
{focus_directive}

PIPELINE STAGES:
You will process this lecture transcript through 3 stages in ONE response.
Do not label the stages — just produce clean, structured markdown output.

STAGE 1 (Understanding): Analyze the transcript carefully through the lens of the student's academic level ({student_level}).

STAGE 2 (Notes): Generate structured lecture notes in this format:

## 📚 Lecture Topic
[Clear topic description adapted for a {student_level} student]

## 🎯 Learning Objectives
[3–5 bullet points: what the student will understand]

## 📖 Key Concepts
[Each major concept as a subheading with explanation tailored to {student_level} depth]

## 💡 Examples & Case Studies  
[Examples the lecturer mentioned, clearly explained]

## 🔑 Key Definitions
[Glossary table: Term | Definition]

## 📝 Summary
[3–4 sentence summary of the whole lecture]

STAGE 3 (Study Enhancement):

## 🎓 Possible Exam Questions
[5 realistic exam questions tailored to {student_level} complexity]

## 📋 Key Terms to Memorize
[5–10 terms with one-line definitions]

## ✅ Revision Checklist
[5–7 self-assessment checkboxes]

## ⚡ Quick Recap
[One paragraph: what must the student know in 30 seconds?]

QUALITY RULES:
- Remove all filler speech (um, uh, like, you know, right?)
- Correct obvious transcription errors
- Use clean markdown formatting throughout
- Subject area detected: {subject} — use appropriate vocabulary for {student_level} level."""

