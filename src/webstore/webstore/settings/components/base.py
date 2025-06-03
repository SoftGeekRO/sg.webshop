ROOT_URLCONF = "webstore.urls"

WSGI_APPLICATION = "webstore.wsgi.application"

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = True

# Celery Configuration Options
CELERY_TIMEZONE = "Europa/Bucharest"
CELERY_TASK_TRACK_STARTED = True
CELERY_TASK_TIME_LIMIT = 30 * 60
