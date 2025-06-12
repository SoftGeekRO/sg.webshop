from django import template
from django.templatetags.static import static
from django.template import TemplateSyntaxError

register = template.Library()


@register.simple_tag
def static_dynamic(path_template, **kwargs):
    """
    Usage: {% static_dynamic "img/{domain}/pwa/16x16.png" domain=domain %}
    """
    try:
        path = path_template.format(**kwargs)
    except KeyError as e:
        raise TemplateSyntaxError(f"Missing variable in static_dynamic tag: {e}")
    return static(path)
