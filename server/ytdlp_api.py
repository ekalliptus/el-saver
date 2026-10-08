"""
yt-dlp API Server - YouTube fallback for ANR Saver
Lightweight REST API that uses yt-dlp to extract video info and serve direct download URLs.

Usage:
  pip install fastapi uvicorn yt-dlp
  API_KEY=your-secret-key uvicorn ytdlp_api:app --host 0.0.0.0 --port 9002

Endpoints:
  POST /info   - Get video info (title, formats, thumbnail)
  POST /download - Get direct download URL
  GET  /health - Health check
"""

import hashlib
import hmac
import html
import ipaddress
import json
import mimetypes
import os
import re
import shutil
import socket
import subprocess
import sys
import threading
import time
import uuid
from html.parser import HTMLParser
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import HTTPRedirectHandler, Request as URLRequest, build_opener

from fastapi import FastAPI, Header, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from pydantic import BaseModel

app = FastAPI(title="yt-dlp API", docs_url=None, redoc_url=None)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

API_KEY = os.getenv("API_KEY", "change-me")
if API_KEY in {"", "change-me"}:
    raise RuntimeError("API_KEY must be set to a strong secret in the environment")
DOWNLOAD_DIR = Path(os.getenv("DOWNLOAD_DIR", "/tmp/ytdlp-downloads"))
DOWNLOAD_DIR.mkdir(parents=True, exist_ok=True)
PUBLIC_BASE_URL = os.getenv("PUBLIC_BASE_URL", "").rstrip("/")
THREADS_MAX_BYTES = 2 * 1024 * 1024
THREADS_TIMEOUT = 10
THREADS_HOSTS = {"threads.net", "www.threads.net", "threads.com", "www.threads.com"}

# Shared with cookie_sync.py: dir holding per-platform Netscape cookie files
# (e.g. youtube.txt). Injected via yt-dlp --cookies so login-gated videos work.
COOKIE_DIR = Path(os.getenv("COOKIE_DIR", "/opt/anrsaver/cookies"))

# Resolve yt-dlp binary: prefer the one in this interpreter's venv (systemd
# runs uvicorn from the venv but its PATH may not include venv/bin), else PATH.
def _resolve_ytdlp() -> str:
    env = os.getenv("YTDLP_BIN")
    if env:
        return env
    venv_bin = Path(sys.executable).parent / "yt-dlp"
    if venv_bin.exists():
        return str(venv_bin)
    return shutil.which("yt-dlp") or "yt-dlp"


YTDLP_BIN = _resolve_ytdlp()


def _host_matches(host: str, domain: str) -> bool:
    return host == domain or host.endswith(f".{domain}")


def _cookie_platform(url: str):
    """Map a URL hostname to its cookie file; YouTube Music uses YouTube."""
    try:
        host = (urlparse(url).hostname or "").lower()
    except ValueError:
        return None
    routes = (
        (("youtube.com", "youtu.be"), "youtube"),
        (("instagram.com", "threads.net", "threads.com"), "instagram"),
        (("twitter.com", "x.com"), "twitter"),
        (("facebook.com", "fb.watch"), "facebook"),
        (("bilibili.tv", "biliintl.com"), "bilibili"),
        (("tiktok.com",), "tiktok"),
    )
    for domains, platform in routes:
        if any(_host_matches(host, domain) for domain in domains):
            return platform
    return None


def _cookie_args(url: str) -> list:
    """Return ['--cookies', path] if a cookie file exists for this platform."""
    platform = _cookie_platform(url)
    if not platform:
        return []
    cookie_file = COOKIE_DIR / f"{platform}.txt"
    return ["--cookies", str(cookie_file)] if cookie_file.exists() else []


class VideoRequest(BaseModel):
    url: str
    quality: str = "720"
    # mode: "video" (default) or "audio" (extract MP3)
    mode: str = "video"


def _check_key(x_api_key: str | None = Header(None)):
    # Missing header -> 401 (Header(None)), not FastAPI's default 422.
    if not x_api_key or not hmac.compare_digest(x_api_key, API_KEY):
        raise HTTPException(401, "Invalid API key")


_rate_lock = threading.Lock()
_rate_hits: dict = {}


def _rate_limit(request: Request, scope: str, limit: int, window_seconds: int):
    """Fixed-window per-IP limiter (uvicorn trusts X-Forwarded-For from the
    localhost Caddy proxy). Shared key in the APK makes per-IP the only
    meaningful dimension."""
    client_ip = request.client.host if request.client else "unknown"
    bucket_key = f"{scope}:{client_ip}"
    now = time.monotonic()
    with _rate_lock:
        recent = [t for t in _rate_hits.get(bucket_key, []) if now - t < window_seconds]
        if len(recent) >= limit:
            raise HTTPException(429, "Terlalu banyak permintaan, coba lagi nanti")
        recent.append(now)
        _rate_hits[bucket_key] = recent


def _run_ytdlp(args: list, timeout: int = 30) -> dict:
    cmd = [YTDLP_BIN, "--no-warnings"] + args
    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout,
        )
        if result.returncode != 0:
            raise Exception(result.stderr.strip() or "yt-dlp failed")
        return {"stdout": result.stdout, "stderr": result.stderr}
    except subprocess.TimeoutExpired:
        raise Exception("Request timed out")


def _classify_error(message: str) -> str:
    """Return a stable machine-readable type without changing HTTP status codes."""
    text = message.lower()
    if any(value in text for value in (
        "confirm you’re not a bot", "confirm you're not a bot",
        "confirm you are not a bot",
    )):
        return "bot-challenge"
    if "http error 429" in text or "too many requests" in text:
        return "temporarily-unavailable"
    if any(value in text for value in (
        "not available in your country", "available in your country",
        "blocked in your country", "geo restricted", "geo-restricted",
    )):
        return "geo-restricted"
    if "drm" in text:
        return "drm-protected"
    if any(value in text for value in (
        "private video", "video is private", "private account", "login required",
        "login to", "login page", "log in to", "sign in to confirm",
        "registered users only", "age-restricted", "channel members",
        "members-only", "members only", "authentication required",
        "requires authentication",
    )):
        return "auth-required"
    if any(value in text for value in (
        "video unavailable", "content unavailable", "no longer available",
        "has been removed", "not found", "unsupported url",
    )):
        return "unavailable"
    if any(value in text for value in (
        "timed out", "timeout", "temporarily unavailable", "connection reset",
        "service unavailable",
    )):
        return "temporarily-unavailable"
    return "extractor-error"


def _error_response(error: Exception, error_type: str = None):
    # Truncate: yt-dlp stderr can be huge and may contain internal paths.
    message = str(error)[:500]
    return JSONResponse(
        status_code=500,
        content={"detail": message, "errorType": error_type or _classify_error(message)},
    )


def _media_metadata(extension: str) -> dict:
    extension = extension.lower()
    if not extension.startswith("."):
        extension = f".{extension}"
    content_type = {
        ".mp3": "audio/mpeg",
        ".m4a": "audio/mp4",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
        ".webp": "image/webp",
        ".gif": "image/gif",
        ".mp4": "video/mp4",
        ".webm": "video/webm",
        ".mov": "video/quicktime",
    }.get(extension, mimetypes.guess_type(f"file{extension}")[0] or "application/octet-stream")
    media_kind = content_type.split("/", 1)[0]
    if media_kind not in {"audio", "image", "video"}:
        media_kind = "video"
    return {"extension": extension, "mediaKind": media_kind, "contentType": content_type}


def _extension_from_url(url: str, fallback: str) -> str:
    suffix = Path(urlparse(url).path).suffix.lower()
    return suffix if suffix and len(suffix) <= 6 else fallback


def _download_response(status: str, url: str, title: str, filename: str,
                       public_base_url: str = None) -> dict:
    base_url = PUBLIC_BASE_URL if public_base_url is None else public_base_url
    if url.startswith("/") and base_url:
        parsed_base = urlparse(base_url)
        if parsed_base.scheme in {"http", "https"} and parsed_base.netloc:
            base_url = parsed_base._replace(query="", fragment="").geturl().rstrip("/")
            url = f"{base_url}{url}"
    return {
        "status": status,
        "url": url,
        "title": title,
        "filename": filename,
        **_media_metadata(Path(filename).suffix or ".mp4"),
    }


def _build_info_response(data: dict) -> dict:
    by_height = {}
    has_audio = False
    for item in data.get("formats", []):
        vcodec = item.get("vcodec", "none")
        acodec = item.get("acodec", "none")
        if acodec != "none" and vcodec == "none":
            has_audio = True
        if vcodec == "none" or not item.get("height"):
            continue
        height = item["height"]
        size = item.get("filesize") or item.get("filesize_approx")
        previous = by_height.get(height)
        if previous is None or (size and (previous["filesize"] or 0) < size):
            extension = f".{item.get('ext') or 'mp4'}"
            by_height[height] = {
                "height": height,
                "ext": extension.removeprefix("."),
                "filesize": size,
                "quality": f"{height}p",
                **_media_metadata(extension),
            }
    formats = sorted(by_height.values(), key=lambda item: item["height"], reverse=True)[:8]
    audio = None
    if has_audio or not formats:
        audio = {
            "quality": "Audio (MP3)", "ext": "mp3", "height": 0,
            "filesize": None, "mode": "audio", **_media_metadata(".mp3"),
        }
    return {
        "status": "ok",
        "title": data.get("title", ""),
        "thumbnail": data.get("thumbnail", ""),
        "duration": data.get("duration"),
        "uploader": data.get("uploader", ""),
        "formats": formats,
        "audio": audio,
    }


class _ThreadsHTMLParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.meta = {}
        self.scripts = []
        self._script = None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "meta":
            name = (attrs.get("property") or attrs.get("name") or "").lower()
            if name.startswith("og:") and attrs.get("content"):
                self.meta[name] = html.unescape(attrs["content"])
        elif tag == "script" and (attrs.get("type") or "").lower() in {
            "application/json", "application/ld+json",
        }:
            self._script = []

    def handle_data(self, data):
        if self._script is not None:
            self._script.append(data)

    def handle_endtag(self, tag):
        if tag == "script" and self._script is not None:
            self.scripts.append("".join(self._script))
            self._script = None


def _safe_media_url(value):
    if not isinstance(value, str):
        return None
    value = html.unescape(value).replace("\\/", "/")
    try:
        parsed = urlparse(value)
        if parsed.scheme not in {"http", "https"} or not parsed.hostname or parsed.username:
            return None
    except ValueError:
        return None
    return value


def _hydration_media(value, key="", media_kind=None):
    video_keys = {"playable_url", "playable_url_quality_hd", "video_url"}
    image_keys = {"image_url", "display_url", "thumbnailurl", "thumbnail_url"}
    contextual_keys = {"url", "contenturl", "content_url"}
    if isinstance(value, dict):
        for child_key, child in value.items():
            child_key = str(child_key).lower()
            child_kind = media_kind
            if child_key in {"video", "video_versions"}:
                child_kind = "video"
            elif child_key in {"image", "image_versions2"}:
                child_kind = "image"
            yield from _hydration_media(child, child_key, child_kind)
    elif isinstance(value, list):
        for child in value:
            yield from _hydration_media(child, key, media_kind)
    else:
        kind = (
            "video" if key in video_keys else
            "image" if key in image_keys else
            media_kind if key in contextual_keys else None
        )
        if kind:
            url = _safe_media_url(value)
            if url:
                yield url, kind


def _parse_threads_html(document: str) -> dict:
    parser = _ThreadsHTMLParser()
    parser.feed(document)
    candidates = [
        (parser.meta.get("og:video"), "video"),
        (parser.meta.get("og:image"), "image"),
    ]
    for script in parser.scripts:
        try:
            candidates.extend(_hydration_media(json.loads(script)))
        except (json.JSONDecodeError, TypeError, ValueError):
            continue
    typed_media = []
    seen = set()
    for candidate, kind in candidates:
        url = _safe_media_url(candidate)
        if not url or url in seen:
            continue
        seen.add(url)
        extension = _extension_from_url(url, ".mp4" if kind == "video" else ".jpg")
        typed_media.append({"url": url, **_media_metadata(extension)})
    # Video posts frequently expose only og:image plus hydration video URLs.
    # Keep videos first so the default quality cannot resolve to the thumbnail.
    media = sorted(typed_media, key=lambda item: item["mediaKind"] != "video")[:8]
    return {
        "title": parser.meta.get("og:title", "Threads post"),
        "description": parser.meta.get("og:description", ""),
        "thumbnail": parser.meta.get("og:image", ""),
        "media": media,
    }


def _validate_source_url(url: str):
    """Reject local/non-HTTP targets before passing a URL to an extractor."""
    try:
        parsed = urlparse(url)
        host = parsed.hostname
        if parsed.scheme not in {"http", "https"} or not host or parsed.username or parsed.password:
            raise ValueError
        normalized = host.lower().rstrip(".")
        if normalized == "localhost" or normalized.isdigit():
            # "2130706433" is not an ipaddress literal but resolvers treat it
            # as 127.0.0.1; reject numeric hosts outright.
            raise ValueError
        try:
            address = ipaddress.ip_address(normalized)
        except ValueError:
            address = None
        if address and not address.is_global:
            raise ValueError
        if address is None:
            # A name that resolves to any non-global IP (DNS rebinding,
            # /etc/hosts tricks, cloud metadata names) is not a media host.
            try:
                resolved = socket.getaddrinfo(normalized, None)
            except socket.gaierror as error:
                raise ValueError from error
            for info in resolved:
                if not ipaddress.ip_address(info[4][0]).is_global:
                    raise ValueError
    except ValueError as error:
        raise ValueError("Only public HTTP(S) URLs are supported") from error


def _validate_threads_url(url: str):
    _validate_source_url(url)
    try:
        parsed = urlparse(url)
        path_parts = [part for part in parsed.path.split("/") if part]
        is_post = len(path_parts) >= 3 and path_parts[0].startswith("@") \
            and path_parts[1] in {"post", "t"}
        if (parsed.scheme != "https" or parsed.hostname not in THREADS_HOSTS or
                parsed.username or parsed.password or parsed.port not in {None, 443} or
                not is_post):
            raise ValueError("Only public HTTPS Threads URLs are supported")
    except ValueError as error:
        raise ValueError("Only public HTTPS Threads URLs are supported") from error


def _is_threads_url(url: str) -> bool:
    try:
        return urlparse(url).hostname in THREADS_HOSTS
    except ValueError:
        return False


class _ThreadsRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        _validate_threads_url(newurl)
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def _extract_threads(url: str) -> dict:
    _validate_threads_url(url)
    request = URLRequest(url, headers={"User-Agent": "Mozilla/5.0 EL-Saver/1.0"})
    try:
        response = build_opener(_ThreadsRedirect).open(request, timeout=THREADS_TIMEOUT)
        content_length = int(response.headers.get("Content-Length", "0"))
        if content_length > THREADS_MAX_BYTES:
            raise ValueError("Threads response too large")
        body = response.read(THREADS_MAX_BYTES + 1)
        if len(body) > THREADS_MAX_BYTES:
            raise ValueError("Threads response too large")
        result = _parse_threads_html(body.decode("utf-8", errors="replace"))
        if not result["media"]:
            raise ValueError("No public Threads media found")
        return result
    except (HTTPError, URLError, OSError, ValueError) as error:
        raise Exception(f"Threads temporarily unavailable: {error}") from error


def _threads_info(data: dict) -> dict:
    formats = []
    for index, item in enumerate(data["media"], 1):
        extension = item["extension"]
        formats.append({
            "quality": f"{item['mediaKind'].title()} {index}",
            "height": index,
            "ext": extension.removeprefix("."),
            "filesize": None,
            **item,
        })
    return {
        "status": "ok", "title": data["title"], "thumbnail": data["thumbnail"],
        "duration": None, "uploader": "", "formats": formats[:8], "audio": None,
        "description": data["description"], "experimentalExtractor": "threads-public",
    }


@app.post("/info")
def get_info(req: VideoRequest, request: Request, x_api_key: str = Header()):
    _check_key(x_api_key)
    _rate_limit(request, "info", 40, 60)

    try:
        _validate_source_url(req.url)
        if _is_threads_url(req.url):
            try:
                return _threads_info(_extract_threads(req.url))
            except Exception as error:
                return _error_response(error, "temporarily-unavailable")
        result = _run_ytdlp([
            "-j", "--no-playlist",
            *_cookie_args(req.url),
            req.url,
        ], timeout=60)
        return _build_info_response(json.loads(result["stdout"]))
    except Exception as e:
        return _error_response(e)


@app.post("/download")
def get_download(req: VideoRequest, request: Request, x_api_key: str = Header()):
    """Extract direct download URL or download and serve file"""
    _check_key(x_api_key)
    _rate_limit(request, "download", 20, 60)

    try:
        _validate_source_url(req.url)
        if _is_threads_url(req.url):
            try:
                data = _extract_threads(req.url)
            except Exception as error:
                return _error_response(error, "temporarily-unavailable")
            selected = req.quality.replace("p", "")
            index = int(selected) - 1 if selected.isdigit() and selected != "720" else 0
            if index < 0 or index >= len(data["media"]):
                return _error_response(Exception("Threads media unavailable"), "unavailable")
            item = data["media"][index]
            filename = f"{data['title']}{item['extension']}"
            return _download_response("redirect", item["url"], data["title"], filename)

        # Audio-only: extract to MP3 server-side and serve the file.
        if req.mode == "audio":
            return _download_audio(req.url)

        height = req.quality.replace("p", "")
        # height goes into the yt-dlp format spec; only plain numbers allowed.
        if not re.fullmatch(r"\d{3,4}", height):
            return _error_response(Exception(f"Invalid quality: {req.quality}"), "unavailable")

        # YouTube's googlevideo URLs are locked to the extractor's IP, so a
        # redirect would be unfetchable from the user's device. Download on the
        # server and serve the file instead.
        is_youtube = _cookie_platform(req.url) == "youtube"
        if is_youtube:
            return _download_merged(req.url, height)

        # Other platforms: prefer a progressive (muxed) stream and hand back a
        # direct URL with no server-side merge. Fall back to merge if needed.
        muxed_spec = (
            f"best[height<={height}][ext=mp4]/best[height<={height}]/best"
        )

        # One extraction that yields BOTH url and title (avoids a 2nd ~20s call)
        result = _run_ytdlp([
            "-f", muxed_spec,
            "--no-playlist",
            "--print", "%(urls)s|@@|%(title)s|@@|%(ext)s",
            *_cookie_args(req.url),
            req.url,
        ], timeout=60)

        url, separator, metadata = result["stdout"].strip().partition("|@@|")
        title, separator2, extension = metadata.rpartition("|@@|")
        if separator and separator2 and url.startswith("http") and "\n" not in url:
            # Single progressive URL - direct download possible
            extension = extension.strip() or "mp4"
            title = title.strip() or "video"
            return _download_response(
                "redirect", url, title, f"{title}.{extension}",
            )
        else:
            # No muxed stream - fall back to server-side merge
            return _download_merged(req.url, height)

    except Exception as e:
        return _error_response(e)


def _download_and_serve(url: str, fmt_args: list, fallback_glob: str,
                        served_ext: str, default_title: str, empty_error: str) -> dict:
    """Run yt-dlp with a unique output token, then serve the file via /files."""
    token = uuid.uuid4().hex
    out_tmpl = str(DOWNLOAD_DIR / f"{token}.%(ext)s")
    try:
        result = _run_ytdlp([
            *fmt_args,
            "-o", out_tmpl,
            "--no-playlist",
            "--print", "after_move:%(title)s|@@|%(filepath)s",
            *_cookie_args(url),
            url,
        ], timeout=180)

        out = result["stdout"].strip()
        title, _, path_str = out.rpartition("|@@|")
        title = title.strip() or default_title
        final_path = Path(path_str.strip()) if path_str.strip() else None

        if not final_path or not final_path.exists() or final_path.stat().st_size == 0:
            # Fallback: locate any file we wrote for this token
            matches = [m for m in DOWNLOAD_DIR.glob(fallback_glob.format(token=token))
                       if m.stat().st_size > 0]
            if not matches:
                raise Exception(empty_error)
            final_path = matches[0]

        return _download_response(
            "tunnel", f"/files/{final_path.name}", title, f"{title}{served_ext}",
        )
    except Exception:
        for m in DOWNLOAD_DIR.glob(f"{token}.*"):
            m.unlink(missing_ok=True)
        raise


def _download_merged(url: str, height: str) -> dict:
    """Download (merging if needed) and serve the resulting file."""
    format_spec = f"bestvideo[height<={height}]+bestaudio/best[height<={height}]/best"
    return _download_and_serve(
        url,
        ["-f", format_spec, "--merge-output-format", "mp4"],
        fallback_glob="{token}.*",
        served_ext=".mp4",
        default_title="video",
        empty_error="Download failed: empty or missing output",
    )


def _download_audio(url: str) -> dict:
    """Extract audio to MP3 server-side and serve the file."""
    return _download_and_serve(
        url,
        ["-f", "bestaudio/best", "--extract-audio",
         "--audio-format", "mp3", "--audio-quality", "0"],
        fallback_glob="{token}.mp3",
        served_ext=".mp3",
        default_title="audio",
        empty_error="Audio extraction failed: empty output",
    )


# yt-dlp outputs are always written under a uuid token in DOWNLOAD_DIR; the
# whitelist keeps /files from serving anything else.
_SERVED_FILE_RE = re.compile(r"^[0-9a-f]{32}\.(mp4|mp3|mkv|webm|m4a|opus|mov)$")


@app.get("/files/{filename}")
def serve_file(filename: str):
    if not _SERVED_FILE_RE.fullmatch(filename):
        raise HTTPException(404, "File not found")
    filepath = (DOWNLOAD_DIR / filename).resolve()
    if not filepath.is_relative_to(DOWNLOAD_DIR.resolve()):
        raise HTTPException(404, "File not found")
    if not filepath.exists() or filepath.stat().st_size == 0:
        raise HTTPException(404, "File not found")
    media = "audio/mpeg" if filename.lower().endswith(".mp3") else "video/mp4"
    return FileResponse(filepath, media_type=media, filename=filename)


@app.get("/health")
def health():
    try:
        result = subprocess.run(
            [YTDLP_BIN, "--version"], capture_output=True, text=True, timeout=5,
        )
        version = result.stdout.strip()
    except Exception:
        version = "not installed"

    return {"status": "ok", "ytdlp_version": version}
