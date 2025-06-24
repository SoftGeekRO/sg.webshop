import logging
import re
from html import unescape

from django import template
from django.utils.safestring import mark_safe

from pymdownx.slugs import slugify
from pymdownx import emoji
from markdown import Markdown, markdown
from markdown.extensions.codehilite import CodeHiliteExtension
from bleach.css_sanitizer import CSSSanitizer
from bleach.sanitizer import Cleaner

from webstore.utils.markdown.markdown import load_markdown

register = template.Library()

logger = logging.getLogger("django")


# Post-process diagrams like Mermaid
def postprocess_diagrams(html):
    return re.sub(
        r"<code>mermaid\s+([\s\S]*?)</code>",
        lambda m: f'<div class="mermaid">{unescape(m.group(1).strip())}</div>',
        html,
        flags=re.IGNORECASE,
    )


def mermaid_formatter(name, code, options, md):
    return f'<div class="mermaid">{code}</div>'


css_sanitizer = CSSSanitizer()
markdown_extensions = [
    # see: https://facelessuser.github.io/pymdown-extensions/extensions/superfences/
    "pymdownx.superfences",
    # "codehilite",
    # Table support
    "tables",
    # generates table of contents if needed
    "toc",
    # better list behavior
    "sane_lists",
    # newlines become <br>
    "nl2br",
    # see: https://facelessuser.github.io/pymdown-extensions/extensions/extra/
    # all markdown.extensions are pare of extra bundle extension
    "markdown.extensions.footnotes",
    "markdown.extensions.attr_list",
    "markdown.extensions.def_list",
    "markdown.extensions.tables",
    "markdown.extensions.abbr",
    # see: https://facelessuser.github.io/pymdown-extensions/extensions/emoji/
    "pymdownx.emoji",
    # see: https://facelessuser.github.io/pymdown-extensions/extensions/magiclink/
    "pymdownx.magiclink",
    # see: https://facelessuser.github.io/pymdown-extensions/extensions/betterem/
    "pymdownx.betterem",
    # see: https://facelessuser.github.io/pymdown-extensions/extensions/tilde/
    "pymdownx.tilde",
    # see: https://facelessuser.github.io/pymdown-extensions/extensions/tasklist/
    "pymdownx.tasklist",
    # see: https://facelessuser.github.io/pymdown-extensions/extensions/saneheaders/
    "pymdownx.saneheaders",
    # see: https://facelessuser.github.io/pymdown-extensions/extensions/highlight/
    "pymdownx.highlight",
    # CodeHiliteExtension(linenums=True, css_class="syntax", use_pygments=True),
    "webstore.utils.markdown.extensions.youtube",
]

extension_configs = {
    "markdown.extensions.toc": {"slugify": slugify(case="lower", percent_encode=True)},
    "pymdownx.magiclink": {
        "repo_url_shortener": True,
        "repo_url_shorthand": True,
        "provider": "github",
        "user": "facelessuser",
        "repo": "pymdown-extensions",
    },
    "pymdownx.tilde": {"subscript": False},
    "pymdownx.emoji": {
        "emoji_index": emoji.gemoji,
        "emoji_generator": emoji.to_png,
        "alt": "short",
        "options": {
            "attributes": {"align": "absmiddle", "height": "20px", "width": "20px"},
            "image_path": "https://github.githubassets.com/images/icons/emoji/unicode/",
            "non_standard_image_path": "https://github.githubassets.com/images/icons/emoji/",
        },
    },
    "pymdownx.superfences": {
        "custom_fences": [
            {
                "name": "mermaid",
                "class": "mermaid",
                "format": lambda name, code, options, md: f'<div class="mermaid">{code.strip()}</div>',
            }
        ],
    },
    "pymdownx.highlight": {
        "linenums": True,
        "noclasses": True,
        "pygments_style": "monokai",
        "auto_title": True,
    },
    "codehilite": {
        "linenums": True,
        "guess_lang": False,
        "css_class": "syntax",
        "use_pygments": True,
    },
}

# Bleach sanitizer to clean HTML (optional but safe)
cleaner = Cleaner(
    tags=[
        "a",
        "abbr",
        "acronym",
        "b",
        "blockquote",
        "code",
        "em",
        "i",
        "li",
        "ol",
        "strong",
        "ul",
        "h1",
        "h2",
        "h3",
        "p",
        "pre",
        "img",
        "table",
        "thead",
        "tbody",
        "tr",
        "th",
        "td",
        "hr",
        "br",
        "span",
        "div",
        "iframe",
    ],
    attributes={
        "*": ["class", "href", "title", "src", "alt", "style"],
        "img": ["src", "alt", "title"],
        "iframe": ["src", "width", "height", "frameborder", "allow", "allowfullscreen"],
        "div": ["class", "style"],
    },
    css_sanitizer=css_sanitizer,
    protocols=["http", "https", "mailto"],
    strip=True,
)


@register.simple_tag(takes_context=True)
def markdownify(context, file_path, **kwargs):
    raw = load_markdown(file_path, context)

    md = Markdown(
        extensions=markdown_extensions,
        extension_configs=extension_configs,
    )

    md = md.convert(raw)

    html = postprocess_diagrams(md)
    cleaned = cleaner.clean(html).replace("&gt;", ">")

    return mark_safe(cleaned)
