from django.db import models
from django.utils.html import format_html
from .siteSettings import SiteSettings


class SocialMedia(models.Model):
    # Choices for social platforms (icon + name)
    PLATFORM_CHOICES = [
        ("facebook", "Facebook"),
        ("twitter", "Twitter"),
        ("instagram", "Instagram"),
        ("linkedin", "LinkedIn"),
        ("youtube", "YouTube"),
    ]

    siteSettings = models.ForeignKey(SiteSettings, on_delete=models.CASCADE)

    platform = models.CharField(
        max_length=20,
        choices=PLATFORM_CHOICES,
        verbose_name="Social Platform",
    )
    profile_name = models.CharField(max_length=100, verbose_name="Profile Username/URL")
    icon = models.CharField(
        max_length=50, blank=True, help_text="Auto-filled based on platform selection"
    )

    class Meta:
        db_table = "socialMedia"
        verbose_name = "Social Media"
        verbose_name_plural = "Social Media"

    def __str__(self):
        return f"{self.get_platform_display()}: {self.profile_name}"

    def save(self, *args, **kwargs):
        # Auto-set icon class (e.g., using Font Awesome)
        self.icon = f"fa-brands fa-{self.platform}"
        super().save(*args, **kwargs)
