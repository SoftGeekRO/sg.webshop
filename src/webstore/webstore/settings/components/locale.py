from django.utils.translation import gettext_lazy as _

# Internationalization
# https://docs.djangoproject.com/en/5.2/topics/i18n/

LANGUAGE_CODE = "ro_RO"

USE_I18N = True
USE_L10N = True

# https://docs.djangoproject.com/en/5.2/ref/settings/#languages
LANGUAGES = (
    ("ro", _("Romania")),
    ("en", _("English")),
)

# https://docs.djangoproject.com/en/5.2/ref/settings/#locale-paths
LOCALE_PATHS = ("locale/",)

USE_TZ = True
TIME_ZONE = "UTC"

# https://docs.djangoproject.com/en/5.2/ref/settings/#first-day-of-week
FIRST_DAY_OF_WEEK = 1
