import logging
import time
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from routers import auth, ai
import config  # load env and clients on startup

# ===== Logging setup =====
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)
logger = logging.getLogger("voicenotex")

app = FastAPI(
    title="VoiceNoteX API",
    description="AI-powered lecture note-taking backend",
    version="1.0.0"
)

# ===== CORS =====
# For development: allow local IPs. For production, lock this to your domain.
ALLOWED_ORIGINS = [
    "http://localhost",
    "http://localhost:*",
    "http://127.0.0.1",
    "http://127.0.0.1:*",
    # Add your production domain here when deploying
    # "https://yourdomain.com",
]

app.add_middleware(
    CORSMiddleware,
    # Using "*" for development convenience since we're on a local network.
    # For production deployment, replace with ALLOWED_ORIGINS above.
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)


# ===== Request Logging Middleware =====
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    duration = round((time.time() - start) * 1000, 2)
    logger.info(
        f"{request.method} {request.url.path} → {response.status_code} ({duration}ms)"
    )
    return response


# ===== Global Exception Handler =====
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled exception on {request.url.path}: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error. Please try again."}
    )


# ===== Routers =====
app.include_router(auth.router, tags=["auth"])
app.include_router(ai.router, tags=["ai"])


# ===== Health Check =====
@app.get("/health")
async def health():
    from database import db
    db_ok = db is not None
    groq_ok = config.groq_client is not None
    deepgram_ok = config.deepgram_client is not None
    return {
        "status": "ok" if (db_ok and groq_ok and deepgram_ok) else "degraded",
        "database": "connected" if db_ok else "disconnected",
        "groq": "ready" if groq_ok else "not configured",
        "deepgram": "ready" if deepgram_ok else "not configured",
    }


@app.get("/")
async def root():
    return {"message": "VoiceNoteX API is running. Visit /docs for API docs."}
