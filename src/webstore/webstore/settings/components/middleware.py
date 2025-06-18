from typing import Tuple

MIDDLEWARE: Tuple[str, ...] = (
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.contrib.sites.middleware.CurrentSiteMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
    # push request to local thread
    "webstore.middleware.ThreadLocalMiddleware",
    # https://github.com/fabiocaccamo/django-maintenance-mode
    "maintenance_mode.middleware.MaintenanceModeMiddleware",
)
