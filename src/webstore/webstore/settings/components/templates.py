from django.conf import settings

from webstore.settings import BASE_DIR

TEMPLATES = [
    # {
    #     "BACKEND": "django.template.backends.jinja2.Jinja2",
    #     "DIRS": [BASE_DIR / "templates"],
    #     "APP_DIRS": True,
    #     "OPTIONS": {
    #         "auto_reload": settings.DEBUG,
    #         "environment": "webstore.jinja2.environment",
    #     },
    # },
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
                # resolve vars inside the static paths inside the template
                "static_dynamic": "webstore.templatetags.static_extras",
                # load dns-prefetch and preload templatetags for head html
                "resource_hints": "webstore.templatetags.resource_hints",
                # load assets from local or remote and also expose the preloads
                # check also for webpack assets and PWA manifests
                "assets": "webstore.templatetags.assets",
                # use and render markdown files inside the templates
                "markdown": "webstore.templatetags.markdown",
            },
        },
    },
]
