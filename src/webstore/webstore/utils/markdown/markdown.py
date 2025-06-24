import logging
from pathlib import Path
import importlib.util

from django.apps import apps
from django.utils.translation import get_language
from django.utils.safestring import mark_safe
from django.template import Template, Context

logger = logging.getLogger("django")


def load_markdown(
    filename_base: str, context: dict = None, fallback_lang="en", silent=False
) -> str:
    """Search for specific md file inside the markdown of each specified app when dot nottation is present.
    If is without dot notation load the file from the path.

    Also, if no language is specified, load the language from the fallback language.
    last resort try the file without dot notation and render first file found with that name in the mentioned path

    """
    lang = get_language() or fallback_lang
    context = context or {}
    possible_paths = []

    if "." in filename_base:
        # Dot notation: resolve app and relative markdown path
        app_label, *path_parts = filename_base.split(".")
        app_config = apps.get_app_config(app_label)
        markdown_dir = Path(app_config.path) / "markdown"
        base_name = ".".join(path_parts)
        if not path_parts:
            raise ValueError(
                "Missing markdown file name after app name (e.g. 'myapp.about')"
            )
    else:
        # File path notation
        markdown_dir = Path(filename_base).parent
        base_name = Path(filename_base).stem

    # Compose full paths to try (localized, fallback, base without lang)
    for lang_code in [lang, fallback_lang, None]:
        suffix = f".{lang_code}.md" if lang_code else ".md"
        candidate = markdown_dir / f"{base_name}{suffix}"
        possible_paths.append(candidate)

    for path in possible_paths:
        if path.exists():
            raw_md = path.read_text(encoding="utf-8")
            tpl = Template(raw_md)

            rendered = tpl.render(Context(context))
            return rendered

    if silent:
        return f"<!-- Markdown file not found: {filename_base} ({lang}) -->"

    raise FileNotFoundError(
        f"Markdown file not found for base '{filename_base}' (lang: {lang})"
    )
