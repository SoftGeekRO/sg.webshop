from jinja2 import Environment
from jinja2 import pass_context
from django.templatetags.static import static
from django.urls import reverse
from django.conf import settings
from django.template import engines

# from .webpack import webpack_asset, render_preloads
from packages.webpack.templatetags import webpack, render_preloads, webpack_asset


def environment(**options):
    env = Environment(**options)
    env.globals.update(
        {
            "static": static,
            "url": reverse,
            "webpack_asset": webpack_asset,
            "render_preloads": render_preloads,
        }
    )
    return env
