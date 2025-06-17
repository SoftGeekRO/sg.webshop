from os import getenv

DEFAULT_SEO = {
    "TITLE": "SoftGeek Webstore",
    "NAME": "SoftGeek",
    "DESCRIPTION": "Magazin de unelte profesionale, echipamente de siguranță și soluții smart home. Livrare rapidă și prețuri competitive pentru proiectele tale!",
    "KEYWORDS": [
        "magazin online unelte",
        "echipamente protectie munca",
        "panouri solare",
        "casa inteligenta",
        "unelte gradina",
        "scule electrice",
        "sisteme fotovoltaice",
        "dispozitive smart home",
        "echipamente psp",
        "unelte bricolaj",
    ],
    "AUTHOR": "SoftGeek Team",
    "PUBLISHER": "SoftGeek Team",
    "OWNER": "SoftGeek Romania",
    "COPYRIGHT": "© 2025 SoftGeek. Toate drepturile rezervate.",
    "IMAGE": "/static/img/default/brand/1200x630.png",
    "TWITTER_SITE": "@SoftGeekRO",
    "OG_SITE_NAME": "SoftGeek Webstore",
    "THEME_COLOR": "#345212",
}

MAINTENANCE_MODE = False

# the template that will be shown by the maintenance-mode page
MAINTENANCE_MODE_TEMPLATE = "maintenance/503.html"

# check the resource_hints templatetags
DNS_PREFETCH_DOMAINS = getenv("DNS_PREFETCH_DOMAINS").split(",")
# check the resource_hints templatetags
# Known domains with their resource type and if crossorigin is needed
DOMAIN_HINTS = {
    "fonts.googleapis.com": {"type": "text/css", "crossorigin": False},
    "fonts.gstatic.com": {"type": "font/woff2", "crossorigin": True},
    "use.fontawesome.com": {"type": "font/woff2", "crossorigin": True},
    "cdn.jsdelivr.net": {"type": "script", "crossorigin": True},
}
