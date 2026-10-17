"""
database.py
===========
MongoDB Database Connection for VoiceNoteX

This file connects the backend to MongoDB and sets up all the
collections (tables) and indexes (for fast searching).

COLLECTIONS:
- users     → student accounts (email, password hash, name)
- chats     → AI chat sessions and message history
- lectures  → saved lecture recordings and AI notes
- feedback  → student feedback on note quality (NEW)

INDEXES:
Indexes make database searches much faster. Without indexes,
MongoDB has to check every record — like searching a book without
an index. With indexes, it jumps directly to the right page.
"""

import os
from pymongo import MongoClient
from pymongo.errors import ConnectionFailure

# Get MongoDB connection string from environment variable
# Default: connects to local MongoDB on port 27017
MONGO_URI = os.getenv("MONGO_URI", "mongodb://127.0.0.1:27017")

try:
    mongo_client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=5000)
    # Test the connection is actually working
    mongo_client.admin.command("ping")
    print(f"[OK] MongoDB connected at {MONGO_URI}")
except ConnectionFailure as e:
    print(f"[ERROR] MongoDB connection failed: {e}")
    print("   Make sure MongoDB is running:")
    print("   Windows:  net start MongoDB")
    print("   Mac/Linux: sudo systemctl start mongod")
    mongo_client = None

# The main database — all VoiceNoteX data lives here
db = mongo_client["voicenotex"] if mongo_client else None
users = db["users"] if db is not None else None

# Create indexes for performance (safe to run multiple times)
if db is not None:
    try:
        # Users: email must be unique (no duplicate accounts)
        db.users.create_index("email", unique=True)

        # Chats: sort by user + time (most recent first)
        db.chats.create_index([("user_email", 1), ("updated_at", -1)])
        db.chats.create_index("chat_id", unique=True)

        # Lectures: sort by user + time
        db.lectures.create_index([("user_email", 1), ("created_at", -1)])
        db.lectures.create_index("lecture_id", unique=True)

        # NEW: Index for favorites filter
        db.lectures.create_index([("user_email", 1), ("is_favorite", 1)])

        # NEW: Text search index for note searching
        # This allows: db.lectures.find({"$text": {"$search": "recursion"}})
        db.lectures.create_index([
            ("title", "text"),
            ("ai_response", "text"),
            ("ai_title", "text"),
            ("course_code", "text"),
        ], name="lecture_text_search")

        # NEW: Feedback collection index
        db.feedback.create_index([("user_email", 1), ("created_at", -1)])
        db.feedback.create_index("lecture_id")

        print("[OK] MongoDB indexes created")
    except Exception as e:
        # Index creation warnings are okay — indexes may already exist
        print(f"Index note: {e}")
