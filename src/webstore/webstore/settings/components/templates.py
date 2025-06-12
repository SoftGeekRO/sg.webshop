from webstore.settings import BASE_DIR

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [
            BASE_DIR.joinpath("templates"),
        ],
        # "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
                "django.template.context_processors.i18n",
                "django.template.context_processors.media",
                "django.template.context_processors.static",
                "django.template.context_processors.csrf",
                # global context processors
                "webstore.context_processors.settings_export",
                # local apps
                "apps.siteSettings.context_processors.global_seo",
            ],
            "loaders": [
                "django.template.loaders.filesystem.Loader",
                "django.template.loaders.app_directories.Loader",
            ],
            "libraries": {
                "webpack": "packages.webpack.templatetags",
                "static_dynamic": "webstore.templatetags.static_extras",
            },
        },
    },
]
