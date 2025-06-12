import json
import logging
from os import path

from django import template
from django.conf import settings
from django.templatetags.static import StaticNode

logger = logging.getLogger("django")

register = template.Library()
_manifest = None


@register.simple_tag
def webpack(filename):
    global _manifest
    if _manifest is None:
        try:
            with open(settings.WP_MANIFEST_PATH) as f:
                _manifest = json.load(f)
        except FileNotFoundError as e:
            _manifest = {}
    return settings.STATIC_URL + _manifest.get(
        filename, filename
    )  # monkey patch for leading slash in webpack files
