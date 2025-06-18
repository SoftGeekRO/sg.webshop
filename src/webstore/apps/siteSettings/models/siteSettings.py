import logging

from django.db import models
from django.contrib.sites.models import Site

logger = logging.getLogger("django")

class SiteSettings(models.Model):

    site = models.OneToOneField(Site, on_delete=models.PROTECT)
    name = models.CharField(max_length=60)
    short_name = models.CharField(max_length=60)
    description = models.CharField(max_length=160, default="")
    keywords = models.JSONField(max_length=160, default=list)
    publisher = models.CharField(max_length=60, default="")
    owner = models.CharField(max_length=60, default="")
    copyright = models.CharField(max_length=70, default="")
    theme_color = models.CharField(max_length=7, default="")
    background_color = models.CharField(max_length=7, default="")
    maintenance_mode = models.BooleanField(default=False)
    created = models.DateTimeField(auto_now_add=True)
    modified = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "siteSettings"
        verbose_name = "Site setting"
        verbose_name_plural = "Site Settings"
        unique_together = ("name",)

    def __str__(self):
        return self.name

    @property
    def keywords_txt(self):
        """
        Returns a list of keywords associated with this site SEO.
        """
        return ",".join(item["value"] for item in self.keywords)

    @property
    def get_maintenance(self):
        return bool(self.maintenance_mode)
