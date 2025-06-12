import logging
from django import forms
from django.utils.html import format_html

from apps.siteSettings.models import SocialMedia

logger = logging.getLogger("django")


class SocialMediaForm(forms.ModelForm):
    class Meta:
        model = SocialMedia
        fields = "__all__"
        widgets = {
            "platform": forms.Select(
                attrs={
                    "class": "icon-dropdown",
                },
            ),
        }

    def platform_fld(self, obj):
        return format_html(obj.platform)

    platform_fld.allow_tags = True
