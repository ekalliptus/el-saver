import json
import os
import socket
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("API_KEY", "test-api-key")

SERVER_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SERVER_DIR))

import ytdlp_api

_GLOBAL_DNS = [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("93.184.216.34", 0))]


def _req(ip: str = "10.8.0.1"):
    """Minimal FastAPI Request stub so endpoint functions are callable directly."""
    return ytdlp_api.Request(
        scope={"type": "http", "client": (ip, 50000), "headers": []},
    )


THREADS_HTML = """
<html><head>
<meta property="og:title" content="Public thread">
<meta property="og:description" content="A public post">
<meta property="og:image" content="https://cdn.example/thumb.jpg">
<meta property="og:video" content="https://cdn.example/video.mp4">
<script type="application/ld+json">
{"video": {"contentUrl": "https://cdn.example/video.mp4"},
 "carousel": [{"image_url": "https://cdn.example/photo.jpg"},
              {"image_url": "https://cdn.example/photo.jpg"}],
 "video_versions": [{"url": "https://cdn.example/alternate.mp4"}],
 "image_versions2": {"candidates": [{"url": "https://cdn.example/alternate.jpg"}]}}
</script>
</head></html>
"""


class ErrorClassifierTests(unittest.TestCase):
    def test_classifies_common_ytdlp_failures(self):
        cases = {
            "This video is private; login required": "auth-required",
            "Please login to access this content": "auth-required",
            "Redirected to the login page": "auth-required",
            "This private account requires authentication": "auth-required",
            "Sign in to confirm your age": "auth-required",
            "This content is not available in your country": "geo-restricted",
            "The uploader has not made this video available in your country": "geo-restricted",
            "This video is DRM protected": "drm-protected",
            "Available for registered users only": "auth-required",
            "This video is age-restricted; use cookies": "auth-required",
            "This video is only available to channel members": "auth-required",
            "Video blocked in your country": "geo-restricted",
            "Video unavailable": "unavailable",
            "This video is no longer available": "unavailable",
            "HTTP Error 429: Too Many Requests": "temporarily-unavailable",
        }
        for message, expected in cases.items():
            with self.subTest(message=message):
                self.assertEqual(ytdlp_api._classify_error(message), expected)

    def test_youtube_bot_challenge_is_not_user_auth(self):
        for message in (
            "Sign in to confirm you’re not a bot. Use --cookies-from-browser",
            "Sign in to confirm you are not a bot",
        ):
            with self.subTest(message=message):
                self.assertEqual(ytdlp_api._classify_error(message), "bot-challenge")

    def test_endpoint_error_keeps_status_and_detail_and_adds_type(self):
        req = ytdlp_api.VideoRequest(url="https://youtube.com/watch?v=x")
        with patch.object(ytdlp_api, "_run_ytdlp", side_effect=Exception("Video unavailable")), \
             patch("socket.getaddrinfo", return_value=_GLOBAL_DNS):
            response = ytdlp_api.get_info(req, _req(), ytdlp_api.API_KEY)
        self.assertEqual(response.status_code, 500)
        body = json.loads(response.body)
        self.assertEqual(body["detail"], "Video unavailable")
        self.assertEqual(body["errorType"], "unavailable")


class SourceValidationTests(unittest.TestCase):
    def test_accepts_only_public_http_source_urls(self):
        with patch("socket.getaddrinfo", return_value=_GLOBAL_DNS):
            ytdlp_api._validate_source_url("https://example.com/video")
            ytdlp_api._validate_source_url("http://example.com/video")
        for url in (
            "file:///etc/passwd",
            "https://user:pass@example.com/video",
            "https://localhost/video",
            "https://localhost./video",
            "https://127.0.0.1/video",
            "https://[::1]/video",
            "http://2130706433/",
            "not a url",
        ):
            with self.subTest(url=url), self.assertRaises(ValueError):
                ytdlp_api._validate_source_url(url)

    def test_hostname_resolving_to_private_ip_is_rejected(self):
        private_dns = [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("127.0.0.1", 0))]
        with patch("socket.getaddrinfo", return_value=private_dns):
            with self.assertRaises(ValueError):
                ytdlp_api._validate_source_url("https://rebind.example/video")

    def test_unresolvable_hostname_is_rejected(self):
        with patch("socket.getaddrinfo", side_effect=socket.gaierror(1, "Name unknown")):
            with self.assertRaises(ValueError):
                ytdlp_api._validate_source_url("https://nx.example/video")


class CookieRoutingTests(unittest.TestCase):
    def test_routes_bilibili_global_tiktok_and_youtube_music(self):
        cases = {
            "https://www.bilibili.tv/en/video/1": "bilibili",
            "https://biliintl.com/video/1": "bilibili",
            "https://www.tiktok.com/@u/video/1": "tiktok",
            "https://music.youtube.com/watch?v=x": "youtube",
        }
        for url, expected in cases.items():
            with self.subTest(url=url):
                self.assertEqual(ytdlp_api._cookie_platform(url), expected)

    def test_threads_share_instagram_cookie_session(self):
        for url in (
            "https://threads.net/@u/post/x",
            "https://www.threads.com/@u/post/x",
        ):
            self.assertEqual(ytdlp_api._cookie_platform(url), "instagram")

    def test_cookie_routing_uses_hostname_not_substring(self):
        self.assertIsNone(ytdlp_api._cookie_platform("https://youtube.com.evil.test/watch?v=x"))

    def test_cookie_args_select_existing_platform_file(self):
        with tempfile.TemporaryDirectory() as directory:
            cookie_dir = Path(directory)
            (cookie_dir / "tiktok.txt").write_text("cookies")
            with patch.object(ytdlp_api, "COOKIE_DIR", cookie_dir):
                self.assertEqual(
                    ytdlp_api._cookie_args("https://tiktok.com/@u/video/1"),
                    ["--cookies", str(cookie_dir / "tiktok.txt")],
                )


class MetadataTests(unittest.TestCase):
    def test_info_formats_are_deduplicated_capped_and_typed(self):
        formats = []
        for height in (144, 240, 360, 480, 720, 1080, 1440, 2160, 4320):
            formats.append({
                "height": height,
                "vcodec": "avc1",
                "acodec": "none",
                "ext": "webm" if height == 720 else "mp4",
                "filesize": height,
            })
        formats.extend([
            {"height": 720, "vcodec": "avc1", "acodec": "none", "ext": "webm", "filesize": 9999},
            {"vcodec": "none", "acodec": "opus", "ext": "webm"},
        ])
        response = ytdlp_api._build_info_response({"title": "x", "formats": formats})
        self.assertEqual(len(response["formats"]), 8)
        self.assertEqual(len({item["height"] for item in response["formats"]}), 8)
        item = next(item for item in response["formats"] if item["height"] == 720)
        self.assertEqual(item["ext"], "webm")
        self.assertEqual(item["extension"], ".webm")
        self.assertEqual(item["mediaKind"], "video")
        self.assertEqual(item["contentType"], "video/webm")
        self.assertEqual(response["audio"]["extension"], ".mp3")
        self.assertEqual(response["audio"]["mediaKind"], "audio")
        self.assertEqual(response["audio"]["contentType"], "audio/mpeg")

    def test_invalid_public_base_url_keeps_relative_compatibility(self):
        response = ytdlp_api._download_response(
            "tunnel", "/files/a.mp4", "x", "x.mp4",
            public_base_url="javascript:alert(1)",
        )
        self.assertEqual(response["url"], "/files/a.mp4")

    def test_download_metadata_and_public_base_url(self):
        response = ytdlp_api._download_response(
            "tunnel", "/files/a.mp3", "track", "track.mp3",
            public_base_url="https://media.example/base/?redirect=bad",
        )
        self.assertEqual(response["url"], "https://media.example/base/files/a.mp3")
        self.assertEqual(response["extension"], ".mp3")
        self.assertEqual(response["mediaKind"], "audio")
        self.assertEqual(response["contentType"], "audio/mpeg")

    def test_relative_tunnel_url_stays_relative_without_public_base(self):
        response = ytdlp_api._download_response("tunnel", "/files/a.mp4", "x", "x.mp4")
        self.assertEqual(response["url"], "/files/a.mp4")

    def test_direct_download_reports_selected_extension(self):
        req = ytdlp_api.VideoRequest(url="https://example.com/video", quality="720")
        output = "https://cdn.example/video.webm|@@|clip|@@|webm\n"
        with patch.object(ytdlp_api, "_run_ytdlp", return_value={"stdout": output}), \
             patch("socket.getaddrinfo", return_value=_GLOBAL_DNS):
            response = ytdlp_api.get_download(req, _req(), ytdlp_api.API_KEY)
        self.assertEqual(response["filename"], "clip.webm")
        self.assertEqual(response["extension"], ".webm")
        self.assertEqual(response["contentType"], "video/webm")

    def test_multiple_direct_urls_fall_back_to_server_merge(self):
        req = ytdlp_api.VideoRequest(url="https://example.com/video", quality="720")
        output = "https://cdn.example/video\nhttps://cdn.example/audio|@@|clip|@@|mp4\n"
        expected = {"status": "tunnel"}
        with patch.object(ytdlp_api, "_run_ytdlp", return_value={"stdout": output}), \
             patch.object(ytdlp_api, "_download_merged", return_value=expected), \
             patch("socket.getaddrinfo", return_value=_GLOBAL_DNS):
            response = ytdlp_api.get_download(req, _req(), ytdlp_api.API_KEY)
        self.assertEqual(response, expected)

    def test_invalid_quality_is_typed_unavailable(self):
        req = ytdlp_api.VideoRequest(url="https://example.com/video", quality="9;9")
        response = ytdlp_api.get_download(req, _req(), ytdlp_api.API_KEY)
        body = json.loads(response.body)
        self.assertEqual(body["errorType"], "unavailable")


class ThreadsExtractorTests(unittest.TestCase):
    def test_validates_public_threads_hosts_at_url_boundary(self):
        with patch("socket.getaddrinfo", return_value=_GLOBAL_DNS):
            for url in (
                "https://threads.net/@u/post/abc",
                "https://www.threads.com/@u/post/abc",
                "https://threads.net/@u/t/abc",
            ):
                ytdlp_api._validate_threads_url(url)
        for url in (
            "http://threads.net/@u/post/abc",
            "https://threads.net.evil.test/@u/post/abc",
            "https://user:pass@threads.net/@u/post/abc",
            "https://threads.net:444/@u/post/abc",
            "https://threads.net/",
            "https://threads.net/login",
            "https://private.example/post/abc",
        ):
            with self.subTest(url=url), self.assertRaises(ValueError):
                ytdlp_api._validate_threads_url(url)

    def test_threads_redirect_handler_rejects_non_threads_hosts(self):
        handler = ytdlp_api._ThreadsRedirect()
        with self.assertRaises(ValueError):
            handler.redirect_request(
                None, None, 302, "Found", {}, "https://private.example/post/abc",
            )

    def test_threads_fetch_caps_response_size_and_timeout(self):
        class Response:
            headers = {}

            def read(self, size):
                self.requested_size = size
                return b"x" * size

        response = Response()
        opener = unittest.mock.Mock()
        opener.open.return_value = response
        with patch.object(ytdlp_api, "build_opener", return_value=opener), \
             self.assertRaises(Exception):
            ytdlp_api._extract_threads("https://threads.net/@u/post/abc")
        opener.open.assert_called_once()
        self.assertEqual(opener.open.call_args.kwargs["timeout"], ytdlp_api.THREADS_TIMEOUT)
        self.assertEqual(response.requested_size, ytdlp_api.THREADS_MAX_BYTES + 1)

    def test_threads_html_parser_caps_media_before_format_cap(self):
        payload = {"carousel": [
            {"image_url": f"https://cdn.example/{index}.jpg"}
            for index in range(100)
        ]}
        result = ytdlp_api._parse_threads_html(
            f'<script type="application/json">{json.dumps(payload)}</script>'
        )
        self.assertLessEqual(len(result["media"]), 8)

    def test_open_graph_media_kind_does_not_depend_on_url_extension(self):
        result = ytdlp_api._parse_threads_html(
            '<meta property="og:video" content="https://cdn.example/asset?id=v">'
            '<meta property="og:image" content="https://cdn.example/asset?id=i">'
        )
        self.assertEqual(
            [item["mediaKind"] for item in result["media"]],
            ["video", "image"],
        )

    def test_hydration_video_precedes_thumbnail_without_og_video(self):
        payload = {
            "video_versions": [{"url": "https://cdn.example/asset?id=video"}],
            "image_versions2": {"candidates": [
                {"url": "https://cdn.example/asset?id=image"},
            ]},
        }
        result = ytdlp_api._parse_threads_html(
            '<meta property="og:image" content="https://cdn.example/thumb">'
            f'<script type="application/json">{json.dumps(payload)}</script>'
        )
        self.assertEqual(result["media"][0]["mediaKind"], "video")
        self.assertEqual(result["media"][0]["extension"], ".mp4")
        self.assertEqual(result["media"][1]["mediaKind"], "image")
        self.assertEqual(result["media"][1]["extension"], ".jpg")

    def test_parses_open_graph_and_hydration_media_offline(self):
        result = ytdlp_api._parse_threads_html(THREADS_HTML)
        self.assertEqual(result["title"], "Public thread")
        self.assertEqual(result["description"], "A public post")
        self.assertEqual(result["thumbnail"], "https://cdn.example/thumb.jpg")
        self.assertEqual(
            [(item["url"], item["mediaKind"]) for item in result["media"]],
            [
                ("https://cdn.example/video.mp4", "video"),
                ("https://cdn.example/alternate.mp4", "video"),
                ("https://cdn.example/thumb.jpg", "image"),
                ("https://cdn.example/photo.jpg", "image"),
                ("https://cdn.example/alternate.jpg", "image"),
            ],
        )

    def test_threads_info_uses_public_extractor_without_ytdlp(self):
        req = ytdlp_api.VideoRequest(url="https://threads.net/@u/post/abc")
        parsed = ytdlp_api._parse_threads_html(THREADS_HTML)
        with patch.object(ytdlp_api, "_extract_threads", return_value=parsed), \
             patch.object(ytdlp_api, "_run_ytdlp") as run_ytdlp:
            response = ytdlp_api.get_info(req, _req(), ytdlp_api.API_KEY)
        run_ytdlp.assert_not_called()
        self.assertEqual(response["status"], "ok")
        self.assertEqual(response["formats"][0]["extension"], ".mp4")
        self.assertEqual(response["formats"][0]["quality"], "Video 1")
        self.assertEqual(response["formats"][0]["height"], 1)
        self.assertEqual(response["formats"][1]["mediaKind"], "video")
        self.assertEqual(response["formats"][2]["mediaKind"], "image")

    def test_threads_download_returns_selected_public_media(self):
        req = ytdlp_api.VideoRequest(
            url="https://threads.com/@u/post/abc", quality="3",
        )
        parsed = ytdlp_api._parse_threads_html(THREADS_HTML)
        with patch.object(ytdlp_api, "_extract_threads", return_value=parsed):
            response = ytdlp_api.get_download(req, _req(), ytdlp_api.API_KEY)
        self.assertEqual(response["url"], "https://cdn.example/thumb.jpg")
        self.assertEqual(response["mediaKind"], "image")

    def test_threads_download_returns_first_public_media(self):
        req = ytdlp_api.VideoRequest(url="https://threads.com/@u/post/abc")
        parsed = ytdlp_api._parse_threads_html(THREADS_HTML)
        with patch.object(ytdlp_api, "_extract_threads", return_value=parsed):
            response = ytdlp_api.get_download(req, _req(), ytdlp_api.API_KEY)
        self.assertEqual(response["status"], "redirect")
        self.assertEqual(response["url"], "https://cdn.example/video.mp4")
        self.assertEqual(response["mediaKind"], "video")
        self.assertEqual(response["contentType"], "video/mp4")

    def test_threads_invalid_media_selection_is_typed_unavailable(self):
        req = ytdlp_api.VideoRequest(
            url="https://threads.net/@u/post/abc", quality="99",
        )
        parsed = ytdlp_api._parse_threads_html(THREADS_HTML)
        with patch.object(ytdlp_api, "_extract_threads", return_value=parsed):
            response = ytdlp_api.get_download(req, _req(), ytdlp_api.API_KEY)
        body = json.loads(response.body)
        self.assertEqual(body["errorType"], "unavailable")

    def test_threads_fetch_failure_is_typed_temporarily_unavailable(self):
        req = ytdlp_api.VideoRequest(url="https://threads.net/@u/post/abc")
        with patch.object(ytdlp_api, "_extract_threads", side_effect=Exception("Threads fetch failed")):
            response = ytdlp_api.get_info(req, _req(), ytdlp_api.API_KEY)
        body = json.loads(response.body)
        self.assertEqual(response.status_code, 500)
        self.assertEqual(body["errorType"], "temporarily-unavailable")


if __name__ == "__main__":
    unittest.main()
