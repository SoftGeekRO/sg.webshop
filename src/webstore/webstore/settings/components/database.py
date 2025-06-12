# Database
# https://docs.djangoproject.com/en/5.2/ref/settings/#databases

from webstore.settings import ROOT_DIR

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": str(ROOT_DIR.joinpath("db.sqlite3")),
    },
    "zipCodes": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": str(ROOT_DIR.joinpath("romania_zip_codes.sqlite")),
    },
}

# MIGRATION_MODULES = {
#     "sites": "multisite.migrations",
# }

# Default primary key field type
# https://docs.djangoproject.com/en/5.2/ref/settings/#default-auto-field

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
