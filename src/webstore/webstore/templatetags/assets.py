import os
import re
import json
import requests
import logging
from threading import Lock

from django import template
from django.conf import settings
from django.utils.safestring import mark_safe
from django.templatetags.static import static
from urllib.parse import quote

from webstore.threadlocals import add_preload, get_preloads, clear_preloads

register = template.Library()

logger = logging.getLogger("django")


def build_attrs(attrs_dict):
    return " ".join(f'{k}="{v}"' for k, v in attrs_dict.items() if v is not None)


def build_url(asset_path):
    return static(asset_path)


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


# ---------===== Google Fonts =====---------

# === Configuration ===
timeout = 10

FONT_CSS_REGEX = re.compile(
    r'url\((https://[^)]+\.woff2)\) format\([\'"]woff2[\'"]\);.*?font-family: [\'"]([^\'"]+)[\'"];.*?font-style: (\w+);.*?font-weight: (\d+);',
    re.DOTALL,
)
USER_AGENT = getattr(
    settings,
    "GOOGLE_FONTS_USER_AGENT",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36",
)


def format_family(f):
    family_string = re.sub(r"\s+", " ", f.strip())
    return family_string.replace(" ", "+")


def build_google_fonts_url(fonts, display="swap"):
    families = "?family=" + "|".join(format_family(f) for f in fonts)
    return f"https://fonts.googleapis.com/css{families}&display={display}"


def download_google_font(family_str):
    font_links = []
    try:

        response = requests.get(
            build_google_fonts_url([format_family(family_str)]),
            headers={"User-Agent": USER_AGENT},
            timeout=timeout,
        )
        response.raise_for_status()
    except Exception as e:
        logger.warning(f"[GoogleFonts] Failed to fetch CSS for {family_str}: {e}")
        return None

    for match in FONT_CSS_REGEX.finditer(response.text):
        font_url, family, style, weight = match.groups()
        family_dir = os.path.join(settings.FONT_ROOT, family.replace(" ", ""))
        os.makedirs(family_dir, exist_ok=True)
        filename = f"{weight}-{style}.woff2"
        local_path = os.path.join(family_dir, filename)

        if not os.path.exists(local_path):
            try:
                font_response = requests.get(font_url)
                font_response.raise_for_status()
                with open(local_path, "wb") as f:
                    f.write(font_response.content)
            except Exception as e:
                logger.warning(f"[GoogleFonts] Failed to download {font_url}: {e}")
                return None

        href = static(f"fonts/{family.replace(' ', '')}/{filename}")
        font_links.append((href, family, weight, style))

    return font_links


def generate_fallback_links(fonts, display="swap"):
    href = build_google_fonts_url(fonts, display)
    link = []
    preload = f'<link rel="stylesheet" href="{href}">'
    link.append(preload)
    return link


@register.simple_tag
def load_google_fonts(*fonts, source="auto", display="swap", preloads=True):
    """
    Load Google Fonts from local or CDN with preload support.
    """
    links = []
    seen = set()
    use_local = source == "local" or (
        source == "auto" and getattr(settings, "GOOGLE_FONTS_LOCAL", False)
    )

    for font_spec in fonts:
        try:
            font_family, weights = font_spec.split(":")
        except ValueError:
            font_family = font_spec
            weights = "400"

        if use_local:
            result = download_google_font(f"{font_family}:{weights}")
            if result:
                for href, _, _, _ in result:
                    if href not in seen:
                        if preloads:
                            preload_attrs = {
                                "rel": "preload",
                                "as": "font",
                                "href": href,
                                "crossorigin": None,
                            }
                            if href.endswith(".woff2"):
                                preload_attrs["type"] = "font/woff2"
                            elif href.endswith(".woff"):
                                preload_attrs["type"] = "font/woff"
                            elif href.endswith(".ttf"):
                                preload_attrs["type"] = "font/ttf"
                            elif href.endswith(".otf"):
                                preload_attrs["type"] = "font/otf"

                            add_preload(f"<link {build_attrs(preload_attrs)} />")
                        links.append(
                            f'<link rel="stylesheet" as="font" type="font/woff2" href="{href}" crossorigin>'
                        )
                        seen.add(href)
            else:
                href = build_google_fonts_url(fonts, display)
                if preloads:
                    add_preload(f'<link rel="stylesheet" as="style" href="{href}">')
                links.extend(generate_fallback_links(fonts, display))
                break
        else:
            href = build_google_fonts_url(fonts, display)
            if preloads:
                add_preload(f'<link rel="preload" as="style" href="{href}">')
            links.extend(generate_fallback_links(fonts, display))
            break
    return mark_safe("\n".join(links))


# ---------===== Webpack assets =====---------

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
        preload_attrs = {
            "rel": "modulepreload" if module and kind == "script" else "preload",
            "as": kind,
            "href": url,
            "crossorigin": CROSSORIGIN or None,
        }

        if kind == "font":
            if url.endswith(".woff2"):
                preload_attrs["type"] = "font/woff2"
            elif url.endswith(".woff"):
                preload_attrs["type"] = "font/woff"
            elif url.endswith(".ttf"):
                preload_attrs["type"] = "font/ttf"
            elif url.endswith(".otf"):
                preload_attrs["type"] = "font/otf"
        add_preload(f"<link {build_attrs(preload_attrs)} />")

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


# ---------===== Local assets =====---------


# ---------===== Render preloads =====---------
@register.simple_tag
def render_preloads():
    """
    Only render preload tags for fonts (useful for <head>).
    Always uses CDN.
    """
    preloads = get_preloads()
    clear_preloads()

    return mark_safe("\n".join(preloads))
