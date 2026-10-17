"""
models.py
=========
Data Models for VoiceNoteX API

WHAT'S NEW:
- NoteFeedbackRequest: for the feedback system (Helpful / Needs Improvement)
- NoteSearchRequest: for searching saved notes
- FavoriteLectureRequest: for marking lectures as favorites
- ImproveNotesRequest: for requesting AI-improved notes
"""

from pydantic import BaseModel, field_validator
from typing import List, Dict, Optional


# ============================================================
# AUTH MODELS
# ============================================================

class SignupRequest(BaseModel):
    name: str
    email: str
    password: str

    @field_validator("name")
    @classmethod
    def name_not_empty(cls, v):
        v = v.strip()
        if not v:
            raise ValueError("Name cannot be empty")
        if len(v) < 2:
            raise ValueError("Name must be at least 2 characters")
        return v

    @field_validator("email")
    @classmethod
    def email_valid(cls, v):
        v = v.strip().lower()
        if "@" not in v or "." not in v:
            raise ValueError("Invalid email format")
        return v

    @field_validator("password")
    @classmethod
    def password_strong(cls, v):
        if len(v) < 6:
            raise ValueError("Password must be at least 6 characters")
        return v


class LoginRequest(BaseModel):
    email: str
    password: str

    @field_validator("email")
    @classmethod
    def email_lower(cls, v):
        return v.strip().lower()


class ForgotPasswordRequest(BaseModel):
    email: str

    @field_validator("email")
    @classmethod
    def email_lower(cls, v):
        return v.strip().lower()


class ResetPasswordRequest(BaseModel):
    email: str
    otp: str
    new_password: str

    @field_validator("email")
    @classmethod
    def email_lower(cls, v):
        return v.strip().lower()

    @field_validator("new_password")
    @classmethod
    def pw_strong(cls, v):
        if len(v) < 6:
            raise ValueError("Password must be at least 6 characters")
        return v


# ============================================================
# CHAT / AI MODELS
# ============================================================

class PromptRequest(BaseModel):
    prompt: Optional[str] = ""
    email: str
    chat_id: str
    history: Optional[List[Dict[str, str]]] = []
    styles: Optional[List[str]] = ["descriptive"]
    code_request: Optional[bool] = False
    only_code: Optional[bool] = False
    language: Optional[str] = None

    @field_validator("email")
    @classmethod
    def email_lower(cls, v):
        return v.strip().lower()

    @field_validator("prompt")
    @classmethod
    def prompt_strip(cls, v):
        return (v or "").strip()


class NewChatRequest(BaseModel):
    email: str

    @field_validator("email")
    @classmethod
    def email_lower(cls, v):
        return v.strip().lower()


# ============================================================
# LECTURE MODELS
# ============================================================

class LectureCreateRequest(BaseModel):
    email: str
    title: str
    course_code: Optional[str] = None
    instructor: Optional[str] = None
    transcript: str
    lecture_prompt: Optional[str] = None
    ai_response: Optional[str] = None
    ai_title: Optional[str] = None
    chat_id: Optional[str] = None

    @field_validator("email")
    @classmethod
    def email_lower(cls, v):
        return v.strip().lower()

    @field_validator("title")
    @classmethod
    def title_not_empty(cls, v):
        if not v.strip():
            raise ValueError("Title cannot be empty")
        return v.strip()


# ============================================================
# NEW: FEEDBACK MODEL
# ============================================================

class NoteFeedbackRequest(BaseModel):
    """
    Student rates AI-generated notes as 'helpful' or 'improve'.
    Saved to database so the system can track quality over time.
    """
    lecture_id: str
    email: str
    rating: str           # "helpful" or "improve"
    feedback_type: Optional[str] = None   # "too_long", "too_short", "unclear", "missing_content"
    comment: Optional[str] = None

    @field_validator("email")
    @classmethod
    def email_lower(cls, v):
        return v.strip().lower()

    @field_validator("rating")
    @classmethod
    def rating_valid(cls, v):
        valid = ["helpful", "improve"]
        if v.lower() not in valid:
            raise ValueError(f"Rating must be one of: {valid}")
        return v.lower()


# ============================================================
# NEW: IMPROVE NOTES MODEL
# ============================================================

class ImproveNotesRequest(BaseModel):
    """Request to regenerate improved notes based on student feedback."""
    lecture_id: str
    email: str
    feedback_type: Optional[str] = "general"

    @field_validator("email")
    @classmethod
    def email_lower(cls, v):
        return v.strip().lower()


# ============================================================
# NEW: FAVORITE LECTURE MODEL
# ============================================================

class FavoriteLectureRequest(BaseModel):
    """Mark or unmark a lecture as a favorite for quick access."""
    lecture_id: str
    email: str
    is_favorite: bool

    @field_validator("email")
    @classmethod
    def email_lower(cls, v):
        return v.strip().lower()


# ============================================================
# NEW: NOTE SEARCH MODEL
# ============================================================

class NoteSearchRequest(BaseModel):
    """Search through saved lecture notes by keyword."""
    email: str
    query: str
    limit: Optional[int] = 20

    @field_validator("email")
    @classmethod
    def email_lower(cls, v):
        return v.strip().lower()

    @field_validator("query")
    @classmethod
    def query_not_empty(cls, v):
        if not v.strip():
            raise ValueError("Search query cannot be empty")
        return v.strip()

    @field_validator("limit")
    @classmethod
    def limit_range(cls, v):
        if v is None:
            return 20
        return max(1, min(v, 50))
