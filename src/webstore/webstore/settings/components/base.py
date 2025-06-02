from pathlib import Path


from django.conf import settings

from webstore.settings import BASE_DIR

ROOT_URLCONF = "webstore.urls"

WSGI_APPLICATION = "webstore.wsgi.application"

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = True
