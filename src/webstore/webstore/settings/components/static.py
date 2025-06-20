from os import path, environ, getenv
from typing import Dict, List, Tuple, Union

from webstore.settings import ROOT_DIR

STATICFILES_FINDERS = (
    "django.contrib.staticfiles.finders.FileSystemFinder",
    "django.contrib.staticfiles.finders.AppDirectoriesFinder",
    "compressor.finders.CompressorFinder",
)

STORAGE = {
    "default": {
        "BACKEND": "django.core.files.storage.FileSystemStorage",
    },
    "staticfiles": {
        "BACKEND": "django.contrib.staticfiles.storage.ManifestStaticFilesStorage",
    },
}

# Static files:
# https://docs.djangoproject.com/en/5.2/ref/settings/#std:setting-STATICFILES_DIRS

STATICFILES_DIRS: List[str] = [
    path.join(ROOT_DIR, "resources", "dist"),
    path.join(ROOT_DIR, "resources", "public"),
]

# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/5.2/howto/static-files/

STATIC_URL = getenv("STATIC_SUBDOMAIN", "/static/")
STATIC_ROOT = path.join(ROOT_DIR, "www", "static")

MEDIA_URL = getenv("MEDIA_SUBDOMAIN", "/media/")
MEDIA_ROOT = path.join(ROOT_DIR, "www", "media")

FONT_URL = f"{STATIC_URL}fonts/"
FONT_ROOT = path.join(ROOT_DIR, "www", "static", "fonts")

GOOGLE_FONTS_LOCAL = False

WP_MANIFEST_PATH = path.join("wp", "manifest.json")
WP_MANIFEST_ROOT = path.join(STATIC_ROOT, WP_MANIFEST_PATH)
