from django.db import models


class SEOMixin(models.Model):
    meta_title = models.CharField("Meta Title", max_length=255, blank=True)
    meta_description = models.TextField("Meta Description", max_length=300, blank=True)
    meta_image = models.ImageField(
        "Meta Image (OG/Twitter)", upload_to="seo/", blank=True, null=True
    )

    class Meta:
        abstract = True

    def get_seo(self):
        return {
            "title": self.meta_title,
            "description": self.meta_description,
            "image": self.meta_image.url if self.meta_image else None,
        }
