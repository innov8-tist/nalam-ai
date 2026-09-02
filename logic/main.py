from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.responses import JSONResponse
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.messages import HumanMessage
from dotenv import load_dotenv
import os
import base64
import requests
from typing import Optional
import uvicorn
import json
import re
from starlette.concurrency import run_in_threadpool
from struct_llm import MedicalTriageResponse
from pydantic import ValidationError

load_dotenv()

app = FastAPI(title="Nalam AI Multimodal API")

GEMINI_KEY = os.getenv("GEMINI_API_KEY")
SARVAM_API_KEY = os.getenv("SARVAM_API") or os.getenv("SARVAM_API_KEY")

# Initialize Gemini model
model = ChatGoogleGenerativeAI(
    model="gemini-2.5-flash",
    temperature=0.7,
    max_tokens=None,
    timeout=None,
    max_retries=2,
    api_key=GEMINI_KEY
)

SYSTEM_PROMPT = """You are Nalam AI, a medical triage assistant. 
Analyze the patient's symptoms and provide a structured response in the following JSON format:

{
  "case": {
    "symptoms": ["symptom1", "symptom2"],
    "duration_days": <number>
  },
  "risk_level": "<green|yellow|red>",
  "immediate_action": {
    "precautions": ["precaution1", "precaution2"],
    "what_to_do": ["action1", "action2"],
    "warning_signs": ["sign1", "sign2"]
  },
  "follow_up": {
    "scheduled_after_hours": <number>,
    "questions": ["question1", "question2"]
  }
}

Guidelines:
- Risk levels:
  * green: Low risk, home care sufficient
  * yellow: Moderate risk, monitor closely
  * red: High risk, immediate medical attention needed

- immediate_action:
  * precautions: Things to avoid or be careful about RIGHT NOW
  * what_to_do: Immediate remedies, care steps, or actions to take NOW
  * warning_signs: Symptoms that mean "seek immediate medical help"

- follow_up:
  * scheduled_after_hours: When to check back (e.g., 24 hours = next day)
  * questions: Specific questions to ask about their condition at follow-up time

Important: Your response must include ONLY the JSON object, nothing else."""


def convert_audio_to_text(
    audio_bytes: bytes,
    filename: str = "audio.wav",
    content_type: str = "audio/wav",
    language_code: str = "unknown",
) -> str:
    """Convert audio to text using Sarvam API"""
    if not SARVAM_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="Sarvam API key is not configured on the server.",
        )
    if not audio_bytes:
        raise HTTPException(status_code=400, detail="The uploaded audio file is empty.")

    url = "https://api.sarvam.ai/speech-to-text"
    files = {
        "file": (filename, audio_bytes, content_type)
    }
    headers = {
        "api-subscription-key": SARVAM_API_KEY
    }
    data = {
        "model": "saaras:v3",
        "mode": "transcribe",
        "language_code": language_code,
    }

    try:
        response = requests.post(
            url,
            files=files,
            data=data,
            headers=headers,
            timeout=45,
        )
        response.raise_for_status()
        result = response.json()
        raw_transcript = result.get("transcript", "")
        transcript = raw_transcript.strip() if isinstance(raw_transcript, str) else ""
        if not transcript:
            raise HTTPException(
                status_code=422,
                detail="Sarvam could not recognize speech in the recording.",
            )
        return transcript
    except HTTPException:
        raise
    except requests.RequestException as error:
        detail = ""
        if error.response is not None:
            try:
                detail = error.response.json().get("error", {}).get("message", "")
            except (ValueError, AttributeError):
                detail = error.response.text[:300]
        message = detail or str(error)
        raise HTTPException(
            status_code=502,
            detail=f"Sarvam transcription failed: {message}",
        ) from error
    except ValueError as error:
        raise HTTPException(
            status_code=502,
            detail="Sarvam returned an invalid transcription response.",
        ) from error


def encode_image(image_bytes: bytes) -> str:
    """Encode image to base64"""
    return base64.b64encode(image_bytes).decode('utf-8')


def extract_json_from_response(response_text: str) -> dict:
    """Extract JSON from LLM response, handling markdown code blocks and extra text"""
    if not response_text or not isinstance(response_text, str):
        raise ValueError("Response text is empty or not a string")
    try:
        # Try to parse directly first
        return json.loads(response_text)
    except Exception:
        # Remove markdown code blocks if present
        json_match = re.search(r'```(?:json)?\s*(\{.*?\})\s*```', response_text, re.DOTALL)
        if json_match:
            try:
                return json.loads(json_match.group(1))
            except Exception:
                pass
        
        # Try to find JSON object in the text
        json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
        if json_match:
            try:
                return json.loads(json_match.group(0))
            except Exception:
                pass
        
        raise ValueError("No valid JSON found in response")


@app.post("/chat")
async def chat_with_ai(
    text_prompt: Optional[str] = Form(None),
    audio: Optional[UploadFile] = File(None),
    image: Optional[UploadFile] = File(None)
):            
    """
    Chat with Nalam AI using text/audio prompts and optional images
    
    Parameters:
    - text_prompt: Text message (optional if audio is provided)
    - audio: Audio file (will be converted to text via Sarvam)
    - image: Image file to analyze
    """
    print("HIII")
    print(f"[CHAT] Received request: text_prompt={text_prompt[:100] if text_prompt else 'None'}..., has_image={image is not None}, has_audio={audio is not None}")
    try:
        # Get the text prompt from either text or audio
        user_message = text_prompt
        
        if audio and audio.filename:
            audio_bytes = await audio.read()
<<<<<<< HEAD
            user_message = await run_in_threadpool(
                convert_audio_to_text,
                audio_bytes,
                audio.filename or "audio.wav",
                audio.content_type or "audio/wav",
            )
=======
            if len(audio_bytes) > 0:
                user_message = convert_audio_to_text(audio_bytes)
>>>>>>> 68255cdb27864337510dfc537594c67fcca33991
        
        if not user_message:
            raise HTTPException(status_code=400, detail="Either text_prompt or audio must be provided")
        
        # Prepare message content
        message_content = [
            {"type": "text", "text": f"{SYSTEM_PROMPT}\n\nUser: {user_message}"}
        ]
        
        # Add image if provided
        if image and image.filename:
            image_bytes = await image.read()
            if len(image_bytes) > 0:
                image_base64 = encode_image(image_bytes)
                image_type = image.content_type or "image/jpeg"
                
                message_content.append({
                    "type": "image_url",
                    "image_url": {
                        "url": f"data:{image_type};base64,{image_base64}"
                    }
                })
        
        # Create message and get response
        message = HumanMessage(content=message_content)
        response = model.invoke([message])
        print(response)
        # Extract and validate structured JSON
        try:
            json_data = extract_json_from_response(response.content)
            print(json_data)
            validated_response = MedicalTriageResponse(**json_data)
            
            return JSONResponse(content={
                "success": True,
                "user_input": user_message,
                "response": validated_response.model_dump(),
                "has_image": image is not None
            })
        except (json.JSONDecodeError, ValueError, ValidationError) as e:
            # If JSON extraction or validation fails, return raw response
            print(f"Validation or decoding failed, returning raw response: {e}")
            return JSONResponse(content={
                "success": True,
                "user_input": user_message,
                "response": response.content,
                "has_image": image is not None,
                "warning": f"Could not parse structured response: {str(e)}"
            })
        
    except HTTPException as he:
        raise he
    except Exception as e:
        import traceback
        print("EXCEPTION IN CHAT ENDPOINT:")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/transcribe")
async def transcribe_audio(
    audio: UploadFile = File(...),
    language_code: str = Form("unknown"),
):
    """Transcribe a short recording with Sarvam without running triage."""
    audio_bytes = await audio.read()
    transcript = await run_in_threadpool(
        convert_audio_to_text,
        audio_bytes,
        audio.filename or "audio.wav",
        audio.content_type or "audio/wav",
        language_code,
    )
    return {
        "success": True,
        "transcript": transcript,
        "language_code": language_code,
    }


@app.get("/")
async def root():
    return {
        "message": "Nalam AI Multimodal API",
        "endpoints": {
            "/chat": "POST - Send text/audio prompts with optional images",
            "/transcribe": "POST - Convert an audio recording to text with Sarvam",
            "/health": "GET - Check API health"
        }
    }

@app.get("/health")
async def health_check():
    return {"status": "healthy", "api": "Nalam AI"}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
