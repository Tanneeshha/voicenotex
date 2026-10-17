import logging
import random
import bcrypt
from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from models import SignupRequest, LoginRequest, ForgotPasswordRequest, ResetPasswordRequest
from database import users
from config import JWT_SECRET, JWT_ALGORITHM, JWT_EXPIRE_HOURS

router = APIRouter()
logger = logging.getLogger("voicenotex.auth")
security = HTTPBearer(auto_error=False)


# ==============================
# JWT HELPERS
# ==============================
def create_token(email: str) -> str:
    payload = {
        "sub": email,
        "iat": datetime.now(timezone.utc),
        "exp": datetime.now(timezone.utc) + timedelta(hours=JWT_EXPIRE_HOURS),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)) -> str:
    """Dependency: validates JWT and returns the user's email."""
    if not credentials:
        raise HTTPException(status_code=401, detail="Authentication required")
    try:
        payload = jwt.decode(credentials.credentials, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        email: str = payload.get("sub")
        if not email:
            raise HTTPException(status_code=401, detail="Invalid token")
        # Verify user still exists in DB
        if users is None or not users.find_one({"email": email}):
            raise HTTPException(status_code=401, detail="User not found or deleted")
        return email
    except JWTError as e:
        raise HTTPException(status_code=401, detail=f"Token invalid or expired: {e}")


# ==============================
# ENDPOINTS
# ==============================

@router.post("/signup")
async def signup(user: SignupRequest):
    if users is None:
        raise HTTPException(status_code=503, detail="Database unavailable")

    # Normalize email
    email = user.email.strip().lower()

    if users.find_one({"email": email}):
        raise HTTPException(status_code=400, detail="An account with this email already exists")

    hashed_pw = bcrypt.hashpw(user.password.encode(), bcrypt.gensalt())
    users.insert_one({
        "name": user.name.strip(),
        "email": email,
        "password": hashed_pw,
        "created_at": datetime.now(timezone.utc),
    })
    logger.info(f"New user registered: {email}")
    return {"message": "Account created successfully"}


@router.post("/login")
async def login(data: LoginRequest):
    if users is None:
        raise HTTPException(status_code=503, detail="Database unavailable")

    email = data.email.strip().lower()
    user = users.find_one({"email": email})

    # Use same error for both "not found" and "wrong password" — prevents email enumeration
    if not user or not bcrypt.checkpw(data.password.encode(), user["password"]):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    token = create_token(email)
    logger.info(f"User logged in: {email}")
    return {
        "message": "Login successful",
        "token": token,
        "email": email,
        "name": user.get("name", ""),
    }


@router.post("/forgot-password")
async def forgot_password(req: ForgotPasswordRequest):
    if users is None:
        raise HTTPException(status_code=503, detail="Database unavailable")

    email = req.email.strip().lower()
    user = users.find_one({"email": email})

    # Always return success to prevent email enumeration
    if not user:
        logger.warning(f"Forgot-password attempt for non-existent email: {email}")
        return {"message": "If this email exists, an OTP has been sent"}

    otp = str(random.randint(100000, 999999))  # 6-digit OTP
    otp_expiry = datetime.now(timezone.utc) + timedelta(minutes=10)

    users.update_one(
        {"email": email},
        {"$set": {"otp": otp, "otp_expiry": otp_expiry}}
    )

    # TODO: Replace this console log with real email sending (e.g. SendGrid or SMTP)
    # For academic demo, the OTP is shown in the server console and the app shows
    # the message "Check server console for OTP" on the UI.
    print(f"\n{'='*50}")
    print(f"  OTP for {email}: {otp}")
    print(f"  Expires: {otp_expiry.strftime('%H:%M:%S UTC')}")
    print(f"{'='*50}\n")
    logger.info(f"OTP generated for {email} (check console)")

    return {"message": "OTP generated. Check the server console for the 6-digit code."}


@router.post("/reset-password")
async def reset_password(req: ResetPasswordRequest):
    if users is None:
        raise HTTPException(status_code=503, detail="Database unavailable")

    email = req.email.strip().lower()
    user = users.find_one({"email": email})

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Check OTP exists
    if not user.get("otp"):
        raise HTTPException(status_code=400, detail="No OTP was requested. Please request a new one.")

    # Check OTP expiry
    otp_expiry = user.get("otp_expiry")
    if otp_expiry and datetime.now(timezone.utc) > otp_expiry:
        users.update_one({"email": email}, {"$unset": {"otp": "", "otp_expiry": ""}})
        raise HTTPException(status_code=400, detail="OTP has expired. Please request a new one.")

    # Validate OTP
    if user.get("otp") != req.otp.strip():
        raise HTTPException(status_code=400, detail="Invalid OTP")

    # Update password and clear OTP
    hashed_pw = bcrypt.hashpw(req.new_password.encode(), bcrypt.gensalt())
    users.update_one(
        {"email": email},
        {
            "$set": {"password": hashed_pw},
            "$unset": {"otp": "", "otp_expiry": ""}
        }
    )
    logger.info(f"Password reset for: {email}")
    return {"message": "Password reset successfully. Please login with your new password."}


@router.get("/me")
async def get_profile(current_email: str = Depends(verify_token)):
    """Get current user profile. Requires JWT token."""
    user = users.find_one({"email": current_email}, {"password": 0, "otp": 0})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return {
        "email": user["email"],
        "name": user.get("name", ""),
        "created_at": user.get("created_at", ""),
    }
