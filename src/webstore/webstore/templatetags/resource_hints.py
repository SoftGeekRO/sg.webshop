import logging

from django import template
from django.conf import settings
from django.utils.safestring import mark_safe
from django.contrib.sites.models import Site
from urllib.parse import urlparse

register = template.Library()

logger = logging.getLogger("django")


@register.simple_tag
def resource_hints(
    rel="dns-prefetch",
    crossorigin=None,
    extra_domains=None,
    reset=False,
    type=None,
    importance=None,
    fetchpriority=None,
):
    """
    Render <link> resource hints with auto type and crossorigin detection.
    `crossorigin` argument overrides auto-detection.
    """
    _RENDERED_HINTS = set()

    if reset:
        _RENDERED_HINTS.clear()

    domains = set()

    try:
        for site in Site.objects.all():
            if site.domain:
                domains.add(site.domain.strip())
    except Exception:
        pass

    if settings.STATIC_URL.startswith("http"):
        parsed = urlparse(settings.STATIC_URL)
        if parsed.netloc:
            domains.add(parsed.netloc.strip())

    if hasattr(settings, "DNS_PREFETCH_DOMAINS"):
        domains.update([d.strip() for d in settings.DNS_PREFETCH_DOMAINS])

    if extra_domains:
        if isinstance(extra_domains, str):
            extra_domains = [d.strip() for d in extra_domains.split(",")]
        domains.update(extra_domains)

    domains = domains - _RENDERED_HINTS
    _RENDERED_HINTS.update(domains)

    lines = []
    for domain in sorted(domains):
        hint = settings.DOMAIN_HINTS.get(domain, {})
        resolved_type = type or hint.get("type")
        resolved_crossorigin = (
            crossorigin
            if crossorigin is not None
            else ("anonymous" if hint.get("crossorigin") else None)
        )

        attrs = [
            f'rel="{rel}"',
            f'href="//{domain}"',
        ]
        if rel == "preconnect" and resolved_crossorigin:
            attrs.append(f'crossorigin="{resolved_crossorigin}"')
        if resolved_type:
            attrs.append(f'type="{resolved_type}"')
        if importance := importance:
            attrs.append(f'importance="{importance}"')
        if fetchpriority := fetchpriority:
            attrs.append(f'fetchpriority="{fetchpriority}"')

        lines.append(f"<link {' '.join(attrs)}>")
    logger.info(lines)
    return mark_safe("\n".join(lines))
