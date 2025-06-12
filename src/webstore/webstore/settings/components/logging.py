# Logging
# https://docs.djangoproject.com/en/2.2/topics/logging/

from webstore.settings import ROOT_DIR

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "verbose": {
            "format": (
                "%(asctime)s [%(process)d] [%(levelname)s] "
                + "pathname=%(pathname)s lineno=%(lineno)s "
                + "funcname=%(funcName)s %(message)s"
            ),
            "datefmt": "%Y-%m-%d %H:%M:%S",
        },
        "simple": {
            "format": "%(asctime)s [%(levelname)s] %(message)s",
            "datefmt": "%Y-%m-%d %H:%M:%S",
        },
    },
    "handlers": {
        "logfile": {
            "level": "INFO",
            "class": "logging.FileHandler",
            "filename": str(ROOT_DIR.joinpath("var", "log", "django.log")),
            "formatter": "verbose",
        },
        "email_admins": {
            "level": "ERROR",
            "class": "django.utils.log.AdminEmailHandler",
        },
        "console": {
            "level": "INFO",
            "class": "logging.StreamHandler",
            "formatter": "simple",
        },
        "console-verbose": {
            "level": "DEBUG",
            "class": "logging.StreamHandler",
            "formatter": "verbose",
        },
    },
    "loggers": {
        "django_file": {
            "handlers": ["logfile", "email_admins"],
            "level": "DEBUG",
            "propagate": True,
        },
        "django": {
            "handlers": ["console", "logfile", "email_admins"],
            "propagate": True,
            "level": "DEBUG",
        },
        "security": {
            "handlers": ["console-verbose", "logfile"],
            "level": "DEBUG",
            "propagate": False,
        },
    },
}
