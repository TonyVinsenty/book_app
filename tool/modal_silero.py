"""On-demand Silero endpoint for the Verso reader.

Deploy with: modal deploy tool/modal_silero.py
The model and manifest are taken from the already tested local Silero install.
"""

import os
import secrets
from pathlib import Path

import modal


ROOT = Path(__file__).resolve().parents[1]
MODEL = Path(
    os.environ.get(
        "VERSO_SILERO_MODEL_FILE",
        r"E:\AI\TTS\.venv\Lib\site-packages\silero\model\v5_6_ru.pt",
    )
)
MANIFEST = Path(
    os.environ.get("VERSO_SILERO_MANIFEST_FILE", r"E:\AI\TTS\latest_silero_models.yml")
)
TOKEN_FILE = ROOT / ".dart_tool" / "modal-tts-token.txt"

if modal.is_local():
    if not TOKEN_FILE.exists():
        TOKEN_FILE.parent.mkdir(exist_ok=True)
        TOKEN_FILE.write_text(secrets.token_urlsafe(32), encoding="ascii")
    secret = modal.Secret.from_dict({"TTS_TOKEN": TOKEN_FILE.read_text(encoding="ascii")})
else:
    secret = modal.Secret.from_dict({})

image = (
    modal.Image.debian_slim(python_version="3.12")
    .pip_install("torch==2.6.0", index_url="https://download.pytorch.org/whl/cpu")
    .pip_install("silero==0.5.5", "numpy==2.2.6", "soundfile==0.13.1", "fastapi==0.115.12")
    .add_local_file(MODEL, "/opt/verso/v5_6_ru.pt")
    .add_local_file(MANIFEST, "/opt/verso/latest_silero_models.yml")
    .add_local_file(ROOT / "tool" / "silero_server.py", "/opt/verso/silero_server.py")
)

app = modal.App("verso-silero", image=image)


@app.function(
    cpu=1.0,
    memory=2048,
    min_containers=0,
    max_containers=1,
    scaledown_window=60,
    secrets=[secret],
)
@modal.asgi_app()
def serve():
    import io
    import shutil
    import sys

    import numpy as np
    import soundfile as sf
    from fastapi import FastAPI, Header, HTTPException, Request
    from fastapi.responses import Response
    from silero import silero_tts
    import silero

    os.chdir("/opt/verso")
    sys.path.insert(0, "/opt/verso")
    model_dir = Path(silero.__file__).parent / "model"
    model_dir.mkdir(exist_ok=True)
    shutil.copyfile("/opt/verso/v5_6_ru.pt", model_dir / "v5_6_ru.pt")
    model, _ = silero_tts(language="ru", speaker="v5_6_ru")
    api = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)
    voices = {"eugene", "aidar", "xenia", "baya"}

    @api.post("/v1/synthesize")
    async def synthesize(request: Request, x_tts_token: str = Header(default="")):
        if not secrets.compare_digest(x_tts_token, os.environ["TTS_TOKEN"]):
            raise HTTPException(status_code=401)
        body = await request.body()
        if len(body) > 65536:
            raise HTTPException(status_code=413)
        try:
            data = await request.json()
            phrase = data["text"]
            voice = data.get("voice", "eugene")
            if not isinstance(phrase, str) or not phrase.strip() or len(phrase) > 10000:
                raise ValueError("Invalid text")
            if voice not in voices:
                raise ValueError("Invalid voice")
            from silero_server import chunks_of

            parts = list(chunks_of(phrase))
            output = io.BytesIO()
            with sf.SoundFile(
                output, mode="w", samplerate=48000, channels=1,
                subtype="PCM_16", format="WAV",
            ) as wav:
                for index, (part, pause) in enumerate(parts):
                    samples = model.apply_tts(
                        text=part, speaker=voice, sample_rate=48000,
                    ).detach().cpu().numpy()
                    wav.write(samples)
                    if index + 1 < len(parts):
                        wav.write(np.zeros(round(pause * 48000), dtype=np.float32))
        except (KeyError, TypeError, ValueError):
            raise HTTPException(status_code=400, detail="Invalid text")
        return Response(output.getvalue(), media_type="audio/wav")

    return api
