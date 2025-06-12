from pathlib import PurePath
from os import environ
from dotenv import load_dotenv

from split_settings.tools import optional, include

load_dotenv()  # loads the configs from .env

ENV = environ.get("DJANGO_ENV") or "development"

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = PurePath(__file__).parent.parent.parent
ROOT_DIR = (
    BASE_DIR.parent.parent
)  # TODO: in the future find something more logic and automagic

base_settings = [
    "components/base.py",
    "components/apps.py",
    "components/database.py",
    "components/logging.py",
    "components/cache.py",
    "components/static.py",
    "components/middleware.py",
    "components/templates.py",
    "components/locale.py",
    "components/security.py",
    "components/mail.py",
    "components/globals.py",
]

# Include settings:
include(*base_settings)
