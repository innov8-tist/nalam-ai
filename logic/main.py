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

load_dotenv()

app = FastAPI(title="Nalam AI Multimodal API")

GEMINI_KEY = os.getenv("GEMINI_API_KEY")
SARVAM_API_KEY = os.getenv("SARVAM_API")

# Initialize Gemini model
model = ChatGoogleGenerativeAI(
    model="gemini-2.5-flash",
    temperature=0.7,
    max_tokens=None,
    timeout=None,
    max_retries=2,
    api_key=GEMINI_KEY
)

SYSTEM_PROMPT = """You are Nalam AI, a helpful multilingual assistant. 

Key instructions:
- Detect the user's language from their message
- If the user speaks in Malayalam, respond in Malayalam
- If the user speaks in any other language, respond in that same language
- Be natural, conversational, and helpful
- When analyzing images, provide detailed and accurate descriptions
- Maintain context across the conversation"""


def convert_audio_to_text(audio_bytes: bytes) -> str:
    """Convert audio to text using Sarvam API"""
    url = "https://api.sarvam.ai/speech-to-text"
    
    files = {
        'file': ('audio.wav', audio_bytes, 'audio/wav')
    }
    headers = {
        'API-Subscription-Key': SARVAM_API_KEY
    }
    
    try:
        response = requests.post(url, files=files, headers=headers)
        response.raise_for_status()
        result = response.json()
        return result.get('transcript', '')
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Audio conversion failed: {str(e)}")


def encode_image(image_bytes: bytes) -> str:
    """Encode image to base64"""
    return base64.b64encode(image_bytes).decode('utf-8')


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
    
    try:
        # Get the text prompt from either text or audio
        user_message = text_prompt
        
        if audio:
            audio_bytes = await audio.read()
            user_message = convert_audio_to_text(audio_bytes)
        
        if not user_message:
            raise HTTPException(status_code=400, detail="Either text_prompt or audio must be provided")
        
        # Prepare message content
        message_content = [
            {"type": "text", "text": f"{SYSTEM_PROMPT}\n\nUser: {user_message}"}
        ]
        
        # Add image if provided
        if image:
            image_bytes = await image.read()
            image_base64 = encode_image(image_bytes)
            image_type = image.content_type or "image/jpeg"
            
            message_content.append({
                "type": "image_url",
                "image_url": f"data:{image_type};base64,{image_base64}"
            })
        
        # Create message and get response
        message = HumanMessage(content=message_content)
        response = model.invoke([message])
        
        return JSONResponse(content={
            "success": True,
            "user_input": user_message,
            "response": response.content,
            "has_image": image is not None
        })
        
    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/")
async def root():
    return {
        "message": "Nalam AI Multimodal API",
        "endpoints": {
            "/chat": "POST - Send text/audio prompts with optional images",
            "/health": "GET - Check API health"
        }
    }


@app.get("/health")
async def health_check():
    return {"status": "healthy", "api": "Nalam AI"}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)