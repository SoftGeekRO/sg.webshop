from os import path
from typing import Dict, List, Tuple, Union

from webstore.settings import ROOT_DIR

STATICFILES_FINDERS = (
    "django.contrib.staticfiles.finders.FileSystemFinder",
    "django.contrib.staticfiles.finders.AppDirectoriesFinder",
    # "compressor.finders.CompressorFinder",
)

# Static files:
# https://docs.djangoproject.com/en/5.2/ref/settings/#std:setting-STATICFILES_DIRS

# STATICFILES_DIRS: List[str] = [BASE_DIR.joinpath("static")]

# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/5.2/howto/static-files/

STATIC_URL = "/static/"
STATIC_ROOT = path.join(ROOT_DIR, "www", "static")

MEDIA_URL = "/media/"
MEDIA_ROOT = path.join(ROOT_DIR, "www", "media")
