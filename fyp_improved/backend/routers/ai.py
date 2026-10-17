"""
routers/ai.py
=============
AI Router — All AI-related API endpoints for VoiceNoteX

WHAT'S NEW IN THIS VERSION:
- POST /feedback         → Students rate notes (Helpful / Needs Improvement)
- POST /improve-notes    → AI regenerates notes based on feedback
- GET  /search-notes     → Search through saved lecture notes
- POST /favorite         → Mark/unmark a lecture as favorite
- GET  /lectures/{email}?favorites_only=true → Filter favorites
- Session memory maintained through existing history mechanism
"""

import asyncio
import logging
import uuid
from datetime import datetime, timezone
from fastapi import APIRouter, HTTPException, UploadFile, File, Depends, Query
from models import (
    PromptRequest, LectureCreateRequest,
    NoteFeedbackRequest, ImproveNotesRequest,
    FavoriteLectureRequest, NoteSearchRequest,
)
from services import (
    chat_with_llm, transcribe_file_bytes, generate_chat_title,
    trim_history, process_lecture_transcript, improve_notes_from_feedback,
)
from ai_engine.context_assumptions import detect_subject
from config import groq_client
from database import db
from routers.auth import verify_token

router = APIRouter()
logger = logging.getLogger("voicenotex.ai")

MAX_AUDIO_SIZE_MB = 25  # Groq Whisper upload limit


# ============================================================
# HELPERS
# ============================================================

def _db_check():
    """Raise a 503 error if the database is not connected."""
    if db is None:
        raise HTTPException(status_code=503, detail="Database unavailable")


def _format_chat(c: dict) -> dict:
    """Format a chat document for API response."""
    return {
        "chat_id": c["chat_id"],
        "last_message": c.get("last_message", "New Chat"),
        "updated_at": (
            c["updated_at"].isoformat()
            if isinstance(c["updated_at"], datetime)
            else str(c.get("updated_at", ""))
        ),
    }


# ============================================================
# CHAT ENDPOINTS
# ============================================================

@router.post("/chat")
async def chat(req: PromptRequest, current_email: str = Depends(verify_token)):
    """
    Send a message to the AI assistant and get a response.

    The AI automatically detects:
    - If this is a lecture transcript → uses 3-stage pipeline
    - If this is a regular question → uses standard chat mode
    """
    _db_check()

    if req.email.lower() != current_email:
        raise HTTPException(status_code=403, detail="Access denied")

    if not groq_client:
        raise HTTPException(status_code=503, detail="AI service not configured")

    if not req.prompt:
        raise HTTPException(status_code=400, detail="Prompt cannot be empty")

    # Fetch existing chat from DB
    chat_doc = db.chats.find_one({"chat_id": req.chat_id, "user_email": current_email})

    # Use provided history, or fall back to stored history (session memory)
    current_history = req.history if req.history else (
        chat_doc["messages"] if chat_doc else []
    )

    # Trim history to avoid token overflow
    current_history = trim_history(current_history)

    try:
        reply, updated_history = chat_with_llm(
            user_message=req.prompt,
            styles=req.styles or ["descriptive"],
            code_request=req.code_request or False,
            only_code=req.only_code or False,
            language=req.language,
            history=current_history,
        )
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))

    updated_history = trim_history(updated_history)

    update_data = {
        "messages": updated_history,
        "updated_at": datetime.now(timezone.utc),
    }

    # Auto-generate title for new chats
    if not chat_doc or chat_doc.get("last_message") in ("New Chat", "", None):
        update_data["last_message"] = generate_chat_title(req.prompt)

    db.chats.update_one(
        {"chat_id": req.chat_id, "user_email": current_email},
        {"$set": update_data},
        upsert=True,
    )

    logger.info(f"Chat message processed for {current_email}, chat: {req.chat_id}")
    return {"response": reply, "chat_id": req.chat_id}


@router.get("/chats/{email}")
async def get_user_chats(email: str, current_email: str = Depends(verify_token)):
    """Get all chat sessions for the current user."""
    _db_check()

    if email.lower() != current_email:
        raise HTTPException(status_code=403, detail="Access denied")

    chats = db.chats.find({"user_email": current_email}).sort("updated_at", -1)
    return [_format_chat(c) for c in chats]


@router.get("/chat-history/{chat_id}")
async def get_chat_history(chat_id: str, current_email: str = Depends(verify_token)):
    """Get the full message history for a specific chat session."""
    _db_check()

    chat_doc = db.chats.find_one({"chat_id": chat_id, "user_email": current_email})
    if not chat_doc:
        return {"messages": []}
    return {"messages": chat_doc.get("messages", [])}


@router.post("/new-chat")
async def create_new_chat(req: dict, current_email: str = Depends(verify_token)):
    """Create a new empty chat session."""
    _db_check()

    email = req.get("email", "").strip().lower()
    if not email:
        raise HTTPException(status_code=400, detail="Email required")
    if email != current_email:
        raise HTTPException(status_code=403, detail="Access denied")

    new_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc)
    db.chats.insert_one({
        "chat_id": new_id,
        "user_email": current_email,
        "messages": [],
        "created_at": now,
        "updated_at": now,
        "last_message": "New Chat",
    })
    return {"chat_id": new_id}


@router.delete("/chats/{email}")
async def clear_user_chats(email: str, current_email: str = Depends(verify_token)):
    """Delete all chat sessions for the current user."""
    _db_check()

    if email.lower() != current_email:
        raise HTTPException(status_code=403, detail="Access denied")

    result = db.chats.delete_many({"user_email": current_email})
    return {"success": True, "deleted_count": result.deleted_count}


@router.delete("/chat/{chat_id}")
async def delete_single_chat(chat_id: str, current_email: str = Depends(verify_token)):
    """Delete a single chat session."""
    _db_check()

    result = db.chats.delete_one({"chat_id": chat_id, "user_email": current_email})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Chat not found")
    return {"success": True}


# ============================================================
# TRANSCRIPTION ENDPOINT
# ============================================================

@router.post("/transcribe")
async def transcribe_audio(
    file: UploadFile = File(...),
    current_email: str = Depends(verify_token)
):
    """
    Convert an uploaded audio file into text using Whisper (large-v3) on Groq.

    Supports: wav, mp3, mp4, webm, ogg, flac, m4a
    Maximum size: 25MB
    """
    if not groq_client:
        raise HTTPException(status_code=503, detail="Transcription service not configured")

    file_bytes = await file.read()

    size_mb = len(file_bytes) / (1024 * 1024)
    if size_mb > MAX_AUDIO_SIZE_MB:
        raise HTTPException(
            status_code=413,
            detail=f"Audio file too large ({size_mb:.1f}MB). Maximum is {MAX_AUDIO_SIZE_MB}MB."
        )

    try:
        transcript = await asyncio.to_thread(transcribe_file_bytes, file_bytes, file.filename or "lecture.m4a")
        logger.info(f"Transcription successful for {current_email}: {len(transcript)} chars")
        return {"transcript": transcript}
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))


# ============================================================
# LECTURE ENDPOINTS
# ============================================================

@router.post("/lectures")
async def save_lecture(req: LectureCreateRequest, current_email: str = Depends(verify_token)):
    """Save a lecture recording with its transcript and AI-generated notes."""
    _db_check()

    if req.email.lower() != current_email:
        raise HTTPException(status_code=403, detail="Access denied")

    ai_title = req.ai_title
    if not ai_title and req.ai_response:
        ai_title = generate_chat_title(req.ai_response)
    elif not ai_title:
        ai_title = generate_chat_title(req.title)

    # Auto-detect subject from transcript
    subject = detect_subject(req.transcript)

    lecture_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc)

    lecture_data = {
        "lecture_id": lecture_id,
        "user_email": current_email,
        "title": req.title,
        "course_code": req.course_code,
        "instructor": req.instructor,
        "transcript": req.transcript,
        "lecture_prompt": req.lecture_prompt or req.transcript,
        "ai_response": req.ai_response,
        "ai_title": ai_title,
        "subject": subject,          # NEW: auto-detected subject
        "chat_id": req.chat_id,
        "created_at": now,
        "is_favorite": False,         # NEW: favorites support
        "feedback": None,             # NEW: feedback field
    }
    db.lectures.insert_one(lecture_data)
    logger.info(f"Lecture saved for {current_email}: {lecture_id} (subject: {subject})")
    return {"success": True, "lecture_id": lecture_id}


@router.get("/lectures/{email}")
async def get_lectures(
    email: str,
    current_email: str = Depends(verify_token),
    favorites_only: bool = Query(False, description="Filter to only favorite lectures"),
    search: str = Query(None, description="Search keyword"),
):
    """
    Get all saved lectures for the current user.

    Optional filters:
    - favorites_only=true → only return starred/favorite lectures
    - search=keyword      → search in title, course code, or notes
    """
    _db_check()

    if email.lower() != current_email:
        raise HTTPException(status_code=403, detail="Access denied")

    # Build MongoDB query
    query = {"user_email": current_email}

    if favorites_only:
        query["is_favorite"] = True

    if search:
        # Text search in title, course_code, ai_response, and transcript
        query["$or"] = [
            {"title": {"$regex": search, "$options": "i"}},
            {"course_code": {"$regex": search, "$options": "i"}},
            {"ai_response": {"$regex": search, "$options": "i"}},
            {"ai_title": {"$regex": search, "$options": "i"}},
        ]

    lectures = db.lectures.find(query).sort("created_at", -1)

    return [
        {
            "lecture_id": l["lecture_id"],
            "title": l["title"],
            "course_code": l.get("course_code"),
            "instructor": l.get("instructor"),
            "subject": l.get("subject", "Academic"),
            "lecture_prompt": l.get("lecture_prompt"),
            "ai_response": l.get("ai_response"),
            "ai_title": l.get("ai_title"),
            "chat_id": l.get("chat_id"),
            "is_favorite": l.get("is_favorite", False),
            "feedback": l.get("feedback"),
            "created_at": l["created_at"].isoformat(),
        }
        for l in lectures
    ]


@router.get("/lecture/{lecture_id}")
async def get_lecture_detail(lecture_id: str, current_email: str = Depends(verify_token)):
    """Get full details of a single lecture."""
    _db_check()

    lecture = db.lectures.find_one({"lecture_id": lecture_id, "user_email": current_email})
    if not lecture:
        raise HTTPException(status_code=404, detail="Lecture not found")

    return {
        "lecture_id": lecture["lecture_id"],
        "title": lecture["title"],
        "course_code": lecture.get("course_code"),
        "instructor": lecture.get("instructor"),
        "subject": lecture.get("subject", "Academic"),
        "transcript": lecture["transcript"],
        "lecture_prompt": lecture.get("lecture_prompt"),
        "ai_response": lecture.get("ai_response"),
        "ai_title": lecture.get("ai_title"),
        "chat_id": lecture.get("chat_id"),
        "is_favorite": lecture.get("is_favorite", False),
        "feedback": lecture.get("feedback"),
        "created_at": lecture["created_at"].isoformat(),
    }


@router.delete("/lecture/{lecture_id}")
async def delete_lecture(lecture_id: str, current_email: str = Depends(verify_token)):
    """Delete a saved lecture."""
    _db_check()

    result = db.lectures.delete_one({"lecture_id": lecture_id, "user_email": current_email})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Lecture not found")
    return {"success": True}


@router.patch("/lecture/{lecture_id}/ai-response")
async def update_lecture_ai_response(
    lecture_id: str,
    req: dict,
    current_email: str = Depends(verify_token)
):
    """Update the AI-generated notes for a lecture."""
    _db_check()

    ai_response = req.get("ai_response")
    if not ai_response:
        raise HTTPException(status_code=400, detail="ai_response is required")

    lecture_prompt = req.get("lecture_prompt")
    ai_title = req.get("ai_title") or generate_chat_title(ai_response)
    chat_id = req.get("chat_id")

    set_data = {"ai_response": ai_response, "ai_title": ai_title}
    if lecture_prompt:
        set_data["lecture_prompt"] = lecture_prompt
    if chat_id:
        set_data["chat_id"] = chat_id

    result = db.lectures.update_one(
        {"lecture_id": lecture_id, "user_email": current_email},
        {"$set": set_data}
    )

    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Lecture not found")

    return {"success": True}


# ============================================================
# NEW: FEEDBACK ENDPOINT
# ============================================================

@router.post("/feedback")
async def submit_feedback(req: NoteFeedbackRequest, current_email: str = Depends(verify_token)):
    """
    Submit feedback on AI-generated notes.

    Students can rate notes as:
    - "helpful"  → The notes were good and useful
    - "improve"  → The notes need to be better

    This feedback is saved in the database for analysis.
    You can use this data in your FYP to show: "X% of notes were rated helpful"
    """
    _db_check()

    if req.email.lower() != current_email:
        raise HTTPException(status_code=403, detail="Access denied")

    # Check the lecture exists and belongs to this user
    lecture = db.lectures.find_one(
        {"lecture_id": req.lecture_id, "user_email": current_email}
    )
    if not lecture:
        raise HTTPException(status_code=404, detail="Lecture not found")

    # Save the feedback
    feedback_data = {
        "rating": req.rating,
        "feedback_type": req.feedback_type,
        "comment": req.comment,
        "submitted_at": datetime.now(timezone.utc).isoformat(),
    }

    db.lectures.update_one(
        {"lecture_id": req.lecture_id, "user_email": current_email},
        {"$set": {"feedback": feedback_data}}
    )

    # Also save to a separate feedback collection for analytics
    db.feedback.insert_one({
        "lecture_id": req.lecture_id,
        "user_email": current_email,
        "rating": req.rating,
        "feedback_type": req.feedback_type,
        "comment": req.comment,
        "created_at": datetime.now(timezone.utc),
    })

    logger.info(f"Feedback '{req.rating}' saved for lecture {req.lecture_id} by {current_email}")
    return {"success": True, "message": f"Thank you for your feedback!"}


# ============================================================
# NEW: IMPROVE NOTES ENDPOINT
# ============================================================

@router.post("/improve-notes")
async def improve_notes(req: ImproveNotesRequest, current_email: str = Depends(verify_token)):
    """
    Automatically regenerate improved lecture notes based on student feedback.

    When a student marks notes as 'Needs Improvement', the AI is asked
    to rewrite the notes based on the specific type of problem.

    This demonstrates a closed feedback loop in the AI system.
    """
    _db_check()

    if req.email.lower() != current_email:
        raise HTTPException(status_code=403, detail="Access denied")

    lecture = db.lectures.find_one(
        {"lecture_id": req.lecture_id, "user_email": current_email}
    )
    if not lecture:
        raise HTTPException(status_code=404, detail="Lecture not found")

    original_notes = lecture.get("ai_response", "")
    if not original_notes:
        raise HTTPException(status_code=400, detail="No AI notes found to improve")

    try:
        improved_notes = await asyncio.to_thread(
            improve_notes_from_feedback, original_notes, req.feedback_type or "general"
        )
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))

    # Save the improved notes
    new_title = generate_chat_title(improved_notes)
    db.lectures.update_one(
        {"lecture_id": req.lecture_id, "user_email": current_email},
        {"$set": {
            "ai_response": improved_notes,
            "ai_title": new_title,
            "improved_at": datetime.now(timezone.utc),
        }}
    )

    logger.info(f"Notes improved for lecture {req.lecture_id} by {current_email}")
    return {"success": True, "improved_notes": improved_notes}


# ============================================================
# NEW: FAVORITE ENDPOINT
# ============================================================

@router.post("/favorite")
async def toggle_favorite(req: FavoriteLectureRequest, current_email: str = Depends(verify_token)):
    """
    Mark or unmark a lecture as a favorite.

    Students can star important lectures for quick access later.
    This is displayed as a star icon in the lecture list.
    """
    _db_check()

    if req.email.lower() != current_email:
        raise HTTPException(status_code=403, detail="Access denied")

    result = db.lectures.update_one(
        {"lecture_id": req.lecture_id, "user_email": current_email},
        {"$set": {"is_favorite": req.is_favorite}}
    )

    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Lecture not found")

    action = "added to" if req.is_favorite else "removed from"
    logger.info(f"Lecture {req.lecture_id} {action} favorites for {current_email}")
    return {"success": True, "is_favorite": req.is_favorite}


# ============================================================
# NEW: SEARCH NOTES ENDPOINT
# ============================================================

@router.get("/search")
async def search_notes(
    email: str,
    q: str = Query(..., description="Search keyword"),
    current_email: str = Depends(verify_token)
):
    """
    Search through all saved lecture notes by keyword.

    Searches in: lecture title, course code, AI notes content, and AI title.
    Returns matching lectures ranked by most recent first.

    Example: GET /search?email=user@email.com&q=recursion
    """
    _db_check()

    if email.lower() != current_email:
        raise HTTPException(status_code=403, detail="Access denied")

    if not q or not q.strip():
        raise HTTPException(status_code=400, detail="Search query cannot be empty")

    query = {
        "user_email": current_email,
        "$or": [
            {"title": {"$regex": q, "$options": "i"}},
            {"course_code": {"$regex": q, "$options": "i"}},
            {"ai_response": {"$regex": q, "$options": "i"}},
            {"ai_title": {"$regex": q, "$options": "i"}},
            {"subject": {"$regex": q, "$options": "i"}},
        ]
    }

    results = db.lectures.find(query).sort("created_at", -1).limit(20)

    return [
        {
            "lecture_id": l["lecture_id"],
            "title": l["title"],
            "course_code": l.get("course_code"),
            "subject": l.get("subject", "Academic"),
            "ai_title": l.get("ai_title"),
            "is_favorite": l.get("is_favorite", False),
            "created_at": l["created_at"].isoformat(),
        }
        for l in results
    ]


# ============================================================
# STATS ENDPOINT — useful for dashboard
# ============================================================

@router.get("/stats/{email}")
async def get_user_stats(email: str, current_email: str = Depends(verify_token)):
    """
    Get statistics for the current user's dashboard.

    Returns:
    - Total lectures recorded
    - Total chats
    - Helpful feedback count
    - Favorite lectures count
    """
    _db_check()

    if email.lower() != current_email:
        raise HTTPException(status_code=403, detail="Access denied")

    total_lectures = db.lectures.count_documents({"user_email": current_email})
    total_chats = db.chats.count_documents({"user_email": current_email})
    favorites = db.lectures.count_documents({"user_email": current_email, "is_favorite": True})
    helpful_feedback = db.feedback.count_documents({
        "user_email": current_email, "rating": "helpful"
    })

    return {
        "total_lectures": total_lectures,
        "total_chats": total_chats,
        "favorites": favorites,
        "helpful_feedback": helpful_feedback,
    }
