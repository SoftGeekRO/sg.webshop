CELERY_RESULT_BACKEND = "django-cache"
# pick which cache from the CACHES setting.
CELERY_CACHE_BACKEND = "default"

CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.locmem.LocMemCache",
        "LOCATION": "unique-snowflake",
    },
    "staticfiles": {
        "BACKEND": "django.core.cache.backends.locmem.LocMemCache",
        "LOCATION": "unique-snowflake",
    },
}
