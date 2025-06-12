import logging
from tldextract import extract as domain_extract

from django.conf import settings
from django.contrib.sites.models import Site

from ..models import SiteSettings

logger = logging.getLogger("django")


def global_seo(request):
    overwrite = request.session.get("seo", {})

    try:
        seo = SiteSettings.objects.get(site__domain=request.site)
    except SiteSettings.DoesNotExist:
        seo = None

    defaults = settings.DEFAULT_SEO

    image = f'{request.build_absolute_uri()}{overwrite.get("image", getattr(seo, "image", defaults.get("IMAGE")))[1:]}'
    domain = domain_extract(request.site.domain).domain

    return {
        "global_seo": {
            "title": overwrite.get(
                "title", getattr(seo, "name", defaults.get("TITLE"))
            ),
            "name": overwrite.get(
                "site_name", getattr(seo, "name", defaults.get("NAME"))
            ),
            "short_name": overwrite.get(
                "site_name", getattr(seo, "short_name", defaults.get("SHORT_NAME"))
            ),
            "author": overwrite.get(
                "author", getattr(seo, "author", defaults.get("AUTHOR"))
            ),
            "copyright": overwrite.get(
                "copyright", getattr(seo, "copyright", defaults.get("COPYRIGHT"))
            ),
            "publisher": overwrite.get(
                "publisher", getattr(seo, "publisher", defaults.get("PUBLISHER"))
            ),
            "owner": overwrite.get(
                "owner", getattr(seo, "owner", defaults.get("OWNER"))
            ),
            "meta_title": overwrite.get(
                "meta_title", getattr(seo, "meta_title", defaults.get("TITLE"))
            ),
            "keywords": overwrite.get(
                "keywords",
                getattr(seo, "keywords_txt", ",".join(defaults.get("KEYWORDS", []))),
            ),
            "description": overwrite.get(
                "description",
                getattr(seo, "description", defaults.get("DESCRIPTION")),
            ),
            "og_image": overwrite.get(
                "description", getattr(seo, "og_image", defaults.get("og_image"))
            ),
            "twitter_handle": overwrite.get(
                "twitter_handle",
                getattr(seo, "twitter_handle", defaults.get("twitter_handle")),
            ),
            "absolut_url": request.build_absolute_uri(),
            "theme_color": overwrite.get(
                "theme_color", getattr(seo, "theme_color", defaults.get("THEME_COLOR"))
            ),
            "og_site_name": overwrite.get(
                "og_site_name",
                getattr(seo, "og_site_name", defaults.get("OG_SITE_NAME")),
            ),
            "image": image,
            "domain": domain,
        }
    }
