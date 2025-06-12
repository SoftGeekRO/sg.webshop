from django.apps import AppConfig


class SitesettingsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.siteSettings"
    verbose_name = "Site Settings"

    def ready(self):
        pass
