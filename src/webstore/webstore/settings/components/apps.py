# Application definition

from typing import Tuple

PREREQ_APPS: Tuple[str, ...] = (
    # "grappelli",
    "django.contrib.admin",
    "django.contrib.admindocs",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "django.contrib.sites",
    "django.contrib.sitemaps",
    # Django Extensions is a collection of custom extensions for the Django Framework.
    # see: Django Extensions is a collection of custom extensions for the Django Framework.
    "django_extensions",
    # A Celery-backed Django Email Backend
    # see: https://github.com/pmclanahan/django-celery-email
    "djcelery_email",
    # see: https://docs.celeryproject.org/en/stable/django/first-steps-with-django.html
    "django_celery_results",
    "django_celery_beat",
    # see: https://django-compressor.readthedocs.io/
    "compressor",
    # see: https://django-import-export.readthedocs.io/en/latest/index.html
    "import_export",
    # see: https://github.com/fabiocaccamo/django-maintenance-mode
    "maintenance_mode",
)

PACKAGES: Tuple[str, ...] = ("packages.tagify",)

PROJECT_APPS: Tuple[str, ...] = (
    "apps.siteSettings",
    "apps.frontpage",
    "apps.brands",
)

# Application definition
INSTALLED_APPS = PREREQ_APPS + PACKAGES + PROJECT_APPS
