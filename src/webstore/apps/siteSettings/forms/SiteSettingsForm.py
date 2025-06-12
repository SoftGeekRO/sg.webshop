import logging

from django import forms
from django.conf import settings
from django.forms.widgets import TextInput, Textarea

from apps.siteSettings.models import SiteSettings

from packages.tagify.widgets import TagsInput

logger = logging.getLogger("django")


class SiteSettingsForm(forms.ModelForm):

    class Meta:
        model = SiteSettings
        fields = "__all__"
        widgets = {
            "description": Textarea(attrs={"maxlength": 120}),
            "theme_color": TextInput(attrs={"type": "color"}),
            "background_color": TextInput(attrs={"type": "color"}),
            "keywords": TagsInput(
                attrs={"placeholder": "Enter your website meta keywords"},
                tagify_settings={"blacklist": ["{}"]},
            ),
        }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        if not self.instance.pk:
            self.fields["owner"].initial = settings.DEFAULT_SEO.get("OWNER")
            self.fields["copyright"].initial = settings.DEFAULT_SEO.get("COPYRIGHT")
            self.fields["publisher"].initial = settings.DEFAULT_SEO.get("PUBLISHER")
            self.fields["description"].initial = settings.DEFAULT_SEO.get("DESCRIPTION")
            self.fields["keywords"].initial = settings.DEFAULT_SEO.get("KEYWORDS")
