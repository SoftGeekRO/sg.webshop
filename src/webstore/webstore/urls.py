"""
URL configuration for webstore project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.2/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""

from django.conf import settings
from django.contrib import admin
from django.urls import path, include
from django.conf.urls.i18n import i18n_patterns
from django.utils import timezone
from django.views.i18n import JavaScriptCatalog
from django.views.decorators.http import last_modified
from django.views.generic.base import TemplateView

admin.autodiscover()

urlpatterns = [
    path("brands/", include("apps.brands.urls", namespace="brands")),
    # path("grappelli/", include("grappelli.urls")),  # grappelli URLS
    path("admin/", admin.site.urls),
    path(
        "robots.txt",
        TemplateView.as_view(template_name="robots.txt", content_type="text/plain"),
    ),
]

front_pags_urls = (
    [path("", include("apps.frontpage.urls"), name="index")],
    "frontpage",
)
webstore_urls = ([], "webstore")

js_info_dict = {
    "domain": "django",
    "packages": getattr(settings, "PROJECT_APPS"),
}

last_modified_date = timezone.now()
urlpatterns += i18n_patterns(
    path("", include(front_pags_urls, namespace="frontpage")),
    path("webstore/", include(webstore_urls, namespace="webstore")),
    path(
        "system.js",
        last_modified(lambda req, **kw: last_modified_date)(
            JavaScriptCatalog.as_view(**js_info_dict)
        ),
        name="javascript-catalog",
    ),
)
