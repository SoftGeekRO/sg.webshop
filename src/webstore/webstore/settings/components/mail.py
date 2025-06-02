from django.apps import apps

ADMINS = [

]

# https://docs.djangoproject.com/en/5.2/ref/settings/#default-from-email
DEFAULT_FROM_EMAIL = ''

# https://docs.djangoproject.com/en/5.2/ref/settings/#email-backend
# The backend to use for sending emails. For the list of available backends see Sending email.
EMAIL_BACKEND = 'djcelery_email.backends.CeleryEmailBackend'

# https://docs.djangoproject.com/en/5.2/ref/settings/#email-host
EMAIL_HOST = 'smtp.gmail.com'

# https://docs.djangoproject.com/en/5.2/ref/settings/#email-port
EMAIL_PORT = 587

# https://docs.djangoproject.com/en/5.2/ref/settings/#email-host-user
EMAIL_HOST_USER = ''

# https://docs.djangoproject.com/en/5.2/ref/settings/#email-host-password
EMAIL_HOST_PASSWORD = ''

# https://docs.djangoproject.com/en/5.2/ref/settings/#email-subject-prefix
EMAIL_SUBJECT_PREFIX = '[SoftGeek Cloud] '

# https://docs.djangoproject.com/en/5.2/ref/settings/#email-use-tls
EMAIL_USE_TLS = True

# https://docs.djangoproject.com/en/5.2/ref/settings/#email-use-ssl
EMAIL_USE_SSL = False

# Timeouts
EMAIL_TIMEOUT = 5

CELERY_EMAIL_TASK_CONFIG = {
	'name': 'djcelery_email_send',
	'queue': 'pg_email',
	'rate_limit': '50/m',  # * CELERY_EMAIL_CHUNK_SIZE (default: 10)
	'ignore_result': False,
}
CELERY_EMAIL_CHUNK_SIZE = 1
