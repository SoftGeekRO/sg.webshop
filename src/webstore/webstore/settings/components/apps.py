# Application definition

from typing import Tuple

PREREQ_APPS: Tuple[str, ...] = (
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
)

PROJECT_APPS: Tuple[str, ...] = ("brands",)

# Application definition
INSTALLED_APPS = PREREQ_APPS + PROJECT_APPS
