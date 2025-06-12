import logging

from django.contrib import admin
from django.utils.html import format_html

from .forms import SiteSettingsForm, SocialMediaForm
from apps.siteSettings.models import SiteSettings, SocialMedia

logger = logging.getLogger("django_file")


class SocialMediaAdmin(admin.ModelAdmin):
    model = SocialMedia
    form = SocialMediaForm
    extra = 0
    readonly_fields = ("icon",)

    fieldsets = [(None, {"fields": (("platform_fld", "profile_name", "icon"),)})]

    class Media:
        # Add Font Awesome for icons
        css = {"all": ("wp/css/fontAwesome.css",)}

    def platform_fld(self, obj):
        return format_html(obj.platform)

    platform_fld.allow_tags = True


@admin.register(SiteSettings)
class SiteSettingsAdmin(admin.ModelAdmin):
    form = SiteSettingsForm
    # inlines = (SocialMediaAdmin,)

    list_display = (
        "site",
        "name",
        "short_name",
        "description",
        "keywords_txt",
        "publisher",
        "owner",
        "copyright",
        "theme_color_fld",
        "background_color_fld",
    )

    fieldsets = [
        (
            None,
            {
                "fields": (
                    ("site", "name", "short_name"),
                    ("owner", "copyright", "publisher"),
                    ("description", "keywords"),
                    ("theme_color", "background_color"),
                )
            },
        ),
    ]

    class Media:
        css = {"all": ("wp/css/adminCSS.css",)}
        js = ("wp/js/adminJS.js",)
        exclude = ("siteSettings",)

    def get_form(self, request, obj=None, **kwargs):
        """
        Don't allow widgets on Foreigner Site dropdown box
        """
        form = super(SiteSettingsAdmin, self).get_form(request, obj, **kwargs)
        form.base_fields["site"].widget.can_add_related = False
        form.base_fields["site"].widget.can_change_related = False
        form.base_fields["site"].widget.can_delete_related = False
        form.base_fields["site"].widget.can_view_related = False
        return form

    def theme_color_fld(self, obj):
        return format_html(
            f'<span class="admin-color-box" style="background-color:{obj.theme_color};font-size:1.3em;"></span>'
        )

    theme_color_fld.short_description = "Theme color"
    theme_color_fld.allow_tags = True

    def background_color_fld(self, obj):
        return format_html(
            f'<span class="admin-color-box" style="background-color:{obj.background_color};font-size:1.3em;"></span>'
        )

    background_color_fld.short_description = "Theme color"
    background_color_fld.allow_tags = True
