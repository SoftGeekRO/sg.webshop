import logging

from django.contrib.sites.models import Site

from maintenance_mode.backends import AbstractStateBackend

from webstore.threadlocals import get_current_request

from .models import SiteSettings

logger = logging.getLogger("django")


class MaintenanceBackend(AbstractStateBackend):

    def get_value(self):
        request = get_current_request()
        if request is None:
            return True

        try:
            current_site = Site.objects.get(domain=request.get_host())
        except Site.DoesNotExist:
            return True

        try:
            site_settings = SiteSettings.objects.get(site=current_site)
            return site_settings.get_maintenance
        except SiteSettings.DoesNotExist:
            return True
