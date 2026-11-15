"""One-user LAN TTS server for the reader (Silero v5_6_ru / eugene).

Run with the Python environment in E:\\AI\\TTS. The server keeps the model in
memory and caches generated WAV files. Do not forward its port to the internet.
"""

import argparse
import hashlib
import json
import re
import secrets
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import numpy as np
import soundfile as sf
from silero import silero_tts


RATE = 48000
MAX_CHARS = 130
MAX_REQUEST = 65536
VOICES = {"eugene", "aidar", "xenia", "baya"}


class BodyError(Exception):
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status


def chunks_of(text: str):
    for paragraph in re.split(r"\n\s*\n", text.strip()):
        words = paragraph.split()
        if not words:
            continue
        chunk = []
        size = 0
        for word in words:
            if len(word) > MAX_CHARS:
                raise ValueError("A word is too long")
            if size + len(word) + (1 if chunk else 0) > MAX_CHARS:
                yield " ".join(chunk), 0.2
                chunk, size = [], 0
            chunk.append(word)
            size += len(word) + (1 if len(chunk) > 1 else 0)
        if chunk:
            yield " ".join(chunk), 0.55


class TtsServer(ThreadingHTTPServer):
    def __init__(self, address, model, token, cache_dir):
        super().__init__(address, Handler)
        self.model = model
        self.token = token
        self.cache_dir = cache_dir
        self.model_lock = threading.Lock()

    def synthesize(self, text, voice="eugene"):
        key = hashlib.sha256((f"v5_6_ru/{voice}\0" + text).encode()).hexdigest()
        target = self.cache_dir / f"{key}.wav"
        if target.exists():
            return target
        with self.model_lock:
            if target.exists():
                return target
            parts = list(chunks_of(text))
            if not parts:
                raise ValueError("Text is empty")
            temporary = target.with_suffix(".partial")
            try:
                with sf.SoundFile(
                    temporary, mode="w", samplerate=RATE, channels=1,
                    subtype="PCM_16", format="WAV",
                ) as wav:
                    for index, (part, pause) in enumerate(parts):
                        samples = self.model.apply_tts(
                            text=part, speaker=voice, sample_rate=RATE
                        ).detach().cpu().numpy()
                        wav.write(samples)
                        if index + 1 < len(parts):
                            wav.write(np.zeros(round(pause * RATE), dtype=np.float32))
                temporary.replace(target)
            finally:
                temporary.unlink(missing_ok=True)
        return target


class Handler(BaseHTTPRequestHandler):
    server: TtsServer

    def read_body(self):
        length_header = self.headers.get("Content-Length")
        transfer = self.headers.get("Transfer-Encoding", "").lower()
        if transfer:
            if transfer != "chunked" or length_header is not None:
                raise BodyError(400, "Invalid transfer encoding")
            body = bytearray()
            while True:
                line = self.rfile.readline(128)
                try:
                    size = int(line.split(b";", 1)[0].strip(), 16)
                except ValueError as error:
                    raise BodyError(400, "Invalid chunk size") from error
                if size == 0:
                    for _ in range(16):
                        if self.rfile.readline(8192) in (b"\r\n", b"\n"):
                            return bytes(body)
                    raise BodyError(400, "Invalid chunk trailer")
                if len(body) + size > MAX_REQUEST:
                    raise BodyError(413, "Request is too large")
                chunk = self.rfile.read(size)
                if len(chunk) != size or self.rfile.read(2) != b"\r\n":
                    raise BodyError(400, "Incomplete chunk")
                body.extend(chunk)
        if length_header is None:
            raise BodyError(411, "Content-Length is required")
        try:
            length = int(length_header)
        except ValueError as error:
            raise BodyError(400, "Invalid Content-Length") from error
        if length <= 0:
            raise BodyError(400, "Empty request")
        if length > MAX_REQUEST:
            raise BodyError(413, "Request is too large")
        body = self.rfile.read(length)
        if len(body) != length:
            raise BodyError(400, "Incomplete request")
        return body

    def send_json(self, code, value):
        data = json.dumps(value, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/health":
            return self.send_json(200, {"status": "ready", "voice": "eugene"})
        self.send_json(404, {"error": "Not found"})

    def do_POST(self):
        if self.path != "/v1/synthesize":
            return self.send_json(404, {"error": "Not found"})
        if not secrets.compare_digest(
            self.headers.get("X-TTS-Token", ""), self.server.token
        ):
            return self.send_json(401, {"error": "Invalid token"})
        try:
            data = json.loads(self.read_body())
            text = data["text"]
            voice = data.get("voice", "eugene")
            if not isinstance(text, str) or not text.strip() or len(text) > 10000:
                return self.send_json(400, {"error": "Invalid text"})
            if voice not in VOICES:
                return self.send_json(400, {"error": "Invalid voice"})
            wav = self.server.synthesize(text, voice)
        except BodyError as error:
            return self.send_json(error.status, {"error": str(error)})
        except (ValueError, KeyError, TypeError, UnicodeDecodeError) as error:
            return self.send_json(400, {"error": str(error)})
        self.send_response(200)
        self.send_header("Content-Type", "audio/wav")
        self.send_header("Content-Length", str(wav.stat().st_size))
        self.send_header("Cache-Control", "private, max-age=86400")
        self.end_headers()
        with wav.open("rb") as source:
            while block := source.read(65536):
                self.wfile.write(block)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--data-dir", type=Path, default=Path(r"E:\AI\TTS"))
    args = parser.parse_args()
    args.data_dir.mkdir(parents=True, exist_ok=True)
    token_file = args.data_dir / "server-token.txt"
    if token_file.exists():
        token = token_file.read_text(encoding="ascii").strip()
    else:
        token = secrets.token_urlsafe(24)
        token_file.write_text(token + "\n", encoding="ascii")
    cache_dir = args.data_dir / "server_cache"
    cache_dir.mkdir(exist_ok=True)
    print("Loading Silero v5_6_ru...", flush=True)
    model, _ = silero_tts(language="ru", speaker="v5_6_ru")
    server = TtsServer((args.host, args.port), model, token, cache_dir)
    print(f"Ready on {args.host}:{args.port}; token: {token}", flush=True)
    print("Press Ctrl+C to stop.", flush=True)
    try:
        server.serve_forever()
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
