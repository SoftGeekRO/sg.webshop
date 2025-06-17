import os
import json
import logging
from threading import Lock

from django.urls import include
from django.utils.safestring import mark_safe
from django.templatetags.static import static
from django.utils.html import format_html
from django import template
from django.conf import settings
from django.templatetags.static import StaticNode

logger = logging.getLogger("django")

register = template.Library()

# === Configuration ===
WEBPACK_MANIFEST_ROOT = settings.WP_MANIFEST_ROOT
USE_MODULE_SCRIPTS = False  # Set to True if using <script type="module">
CROSSORIGIN = ""  # Example: "anonymous"
INTEGRITY_MAP = {}  # Optional: {"js/main.js": "sha384-..."}

_manifest_cache = None
_manifest_lock = Lock()
_manifest = None

# Context keys
INCLUDED_KEY = "webpack_included"


def load_manifest():
    global _manifest_cache
    if _manifest_cache is None:
        with _manifest_lock:
            if _manifest_cache is None:
                try:
                    with open(WEBPACK_MANIFEST_ROOT, "r") as f:
                        _manifest_cache = json.load(f)
                except Exception as e:
                    _manifest_cache = {"__error__": str(e)}
    return _manifest_cache, WEBPACK_MANIFEST_ROOT


def resolve_asset(entry_name, exts, manifest, suffix=None):
    if isinstance(exts, str):
        exts = [exts]
    key = f"{entry_name}"
    if suffix:
        key += f".{suffix}"
    for k, v in manifest.items():
        if k.startswith(key) and any(v.endswith(f".{ext}") for ext in exts):
            return v
    return None


def guess_type(url):
    ext = url.split("?")[0].split(".")[-1].lower()
    if ext in {"js", "mjs"}:
        return "script"
    if ext in {"css"}:
        return "style"
    if ext in {"woff", "woff2", "ttf", "otf"}:
        return "font"
    if ext in {"jpg", "jpeg", "png", "gif", "webp", "svg", "avif"}:
        return "image"
    return None


def build_url(asset_path):
    return static(asset_path)


def build_attrs(attrs_dict):
    return " ".join(f'{k}="{v}"' for k, v in attrs_dict.items() if v is not None)


def collect_assets(entrypoints, suffix=None):
    manifest, path = load_manifest()
    if "__error__" in manifest:
        return [], (
            f"<!-- Webpack manifest error: {manifest['__error__']} -->"
            if settings.DEBUG
            else ""
        )

    entries = [e.strip() for e in entrypoints.split(",")]
    assets = []

    for entry in entries:
        # CSS
        css_path = resolve_asset(entry, "css", manifest, suffix)
        if css_path:
            url = build_url(css_path)
            assets.append(("style", url, css_path))

        # JS
        js_path = resolve_asset(entry, "js", manifest, suffix)
        if js_path:
            url = build_url(js_path)
            assets.append(("script", url, js_path))

        # Fonts
        font_path = resolve_asset(
            entry, ["woff2", "woff", "ttf", "otf"], manifest, suffix
        )
        if font_path:
            url = build_url(font_path)
            assets.append(("font", url, font_path))

        # Images
        img_path = resolve_asset(
            entry,
            ["jpg", "jpeg", "png", "webp", "svg", "gif", "avif"],
            manifest,
            suffix,
        )
        if img_path:
            url = build_url(img_path)
            assets.append(("image", url, img_path))

    return assets, None


@register.simple_tag
def webpack_manifest():
    manifest_content, manifest_path = load_manifest()

    if not "__error__" in manifest_content:
        return static(settings.WP_MANIFEST_PATH)
    return ""


@register.simple_tag
def webpack_asset(entrypoints="main", async_scripts=False, module=False, suffix=None):
    assets, error = collect_assets(entrypoints, suffix)
    if error:
        return mark_safe(error)

    tags = []

    for kind, url, original_path in assets:
        if kind == "style":
            tags.append(f'<link rel="stylesheet" href="{url}" />')
        elif kind == "script":
            attrs = {
                "src": url,
                "defer": None if async_scripts or module else "defer",
                "async": "async" if async_scripts and not module else None,
                "type": "module" if module or USE_MODULE_SCRIPTS else None,
                "crossorigin": CROSSORIGIN or None,
                "integrity": INTEGRITY_MAP.get(original_path),
            }
            tags.append(f"<script {build_attrs(attrs)}></script>")

    return mark_safe("\n".join(tags))


@register.simple_tag
def webpack_preload(entrypoints="main", module=False, suffix=None):
    assets, error = collect_assets(entrypoints, suffix)
    if error:
        return mark_safe(error)

    tags = []

    for kind, url, _ in assets:
        attrs = {
            "rel": "modulepreload" if module and kind == "script" else "preload",
            "as": kind,
            "href": url,
            "crossorigin": CROSSORIGIN or None,
        }

        if kind == "font":
            if url.endswith(".woff2"):
                attrs["type"] = "font/woff2"
            elif url.endswith(".woff"):
                attrs["type"] = "font/woff"
            elif url.endswith(".ttf"):
                attrs["type"] = "font/ttf"
            elif url.endswith(".otf"):
                attrs["type"] = "font/otf"

        tags.append(f"<link {build_attrs(attrs)} />")

    return mark_safe("\n".join(tags))
