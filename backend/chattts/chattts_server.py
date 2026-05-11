import os
import io
import torch
import ChatTTS
import soundfile as sf
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Union
from fastapi.responses import Response
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

# Initialize ChatTTS model
logger.info("Initializing ChatTTS model...")
chat = ChatTTS.Chat()
# force_redownload is optional, but setting compile to False can sometimes help avoid issues on windows
chat.load(compile=False) 
logger.info("ChatTTS model loaded successfully.")

class TTSRequest(BaseModel):
    text: str
    voice: Union[int, str] = 2222 # Can be a seed (int) or an embedding string (str)
    speed: float = 1.0
    prompt: str = ""

@app.post("/tts")
async def synthesize_speech(request: TTSRequest):
    try:
        if not request.text:
            raise HTTPException(status_code=400, detail="Text cannot be empty")
            
        logger.info(f"Synthesizing text: {request.text[:20]}... with voice seed: {request.voice}")
        
        # Determine voice (using seed for random speaker if requested)
        if isinstance(request.voice, int):
            torch.manual_seed(request.voice)
            rand_spk = chat.sample_random_speaker()
            text_seed = request.voice
        else:
            # If it's a string, we treat it as a direct speaker embedding (the "DNA" string)
            # WebUI generated strings usually start with 铇佹钒, we need to pass the raw string
            # to InferCodeParams as it expects the encoded string, not a decoded tensor.
            rand_spk = request.voice
            text_seed = 42 # Fallback text seed since voice is a string
        
        # Prepare parameters
        params_infer_code = ChatTTS.Chat.InferCodeParams(
            spk_emb = rand_spk,
            prompt = request.prompt,
            temperature = 0.3, # 推荐的温度，降低随机性
            manual_seed = text_seed # 锁定文本推理种子，防止语气和性别乱跳
        )
        
        # Run inference
        wavs = chat.infer([request.text], params_infer_code=params_infer_code)
        
        if not wavs or len(wavs) == 0:
            raise HTTPException(status_code=500, detail="Inference failed to produce audio")
            
        audio_data = wavs[0]
        
        # Convert to WAV format in memory
        buffer = io.BytesPath() if hasattr(io, "BytesPath") else io.BytesIO()
        sf.write(buffer, audio_data, 24000, format='WAV')
        buffer.seek(0)
        
        return Response(content=buffer.read(), media_type="audio/wav")
        
    except Exception as e:
        logger.error(f"TTS synthesis error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8080)
