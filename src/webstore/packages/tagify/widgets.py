from django import forms
from django.utils.safestring import mark_safe

# use webpack templatetag because it is already using the webpack manifest to fetch files
from webstore.templatetags.assets import webpack_asset


class TagsInput(forms.Textarea):
    template_name = "tagsinput.html"

    class Media:
        css = {"all": [webpack_asset("tagifyCss.css")]}
        js = [webpack_asset("tagifyJs.js"), webpack_asset("vendor/yaireo-tagify.js")]

    def __init__(self, attrs=None, tagify_settings=None):
        """
        :param tagify_settings: Various settings used to configure Tagify.
        You can specify if 'duplicates' are allowed (boolean).
        You can specify 'autocomplete' (boolean) - this matches from the whitelist.
        You can specify 'enforceWhitelist' (boolean).
        You can specify 'maxTags' (int).
        You can specify the 'whitelist' (string list).
        You can specify the 'blacklist' (string list).
        You can specify the 'delimiter' (string).
        You can specify the RegEx 'pattern' to validate the input (string).
        """
        # TODO validate settings
        super().__init__(attrs)
        self.tagify_settings = tagify_settings or {}

    def get_context(self, name, value, attrs):
        ctx = super().get_context(name, value, attrs)

        if "tagify_settings" not in ctx:
            ctx["tagify_settings"] = self.tagify_settings
        return ctx

    def render(self, name, value, attrs=None, renderer=None):
        input_html = super().render(name, value, attrs, renderer)
        # @TODO: Legacy code, in the future will be removed
        script = ""
        return mark_safe(input_html + script)
