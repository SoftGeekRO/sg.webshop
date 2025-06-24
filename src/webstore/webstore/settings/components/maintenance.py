MAINTENANCE_MODE = None

MAINTENANCE_MODE_STATE_BACKEND = (
    "apps.siteSettings.maintenanceBackend.MaintenanceBackend"
)

# the template that will be shown by the maintenance-mode page
MAINTENANCE_MODE_TEMPLATE = "maintenance/503.html"
# list of urls that will not be affected by the maintenance-mode
# urls will be used to compile regular expressions objects
MAINTENANCE_MODE_IGNORE_URLS = (
    "/robots.txt",
    "/webstore",
    "/favicon.ico",
    "/en/system.js",
)

# if True admin site will not be affected by the maintenance-mode page
MAINTENANCE_MODE_IGNORE_ADMIN_SITE = True

# if True authenticated users will not see the maintenance-mode page
MAINTENANCE_MODE_IGNORE_AUTHENTICATED_USER = False

# if True the staff will not see the maintenance-mode page
MAINTENANCE_MODE_IGNORE_STAFF = False

# if True the superuser will not see the maintenance-mode page
MAINTENANCE_MODE_IGNORE_SUPERUSER = False

# the value in seconds of the Retry-After header during maintenance-mode
MAINTENANCE_MODE_RETRY_AFTER = 3600  # 1 hour

# the HTTP status code to send
MAINTENANCE_MODE_STATUS_CODE = 503

# the absolute url where users will be redirected to during maintenance-mode
MAINTENANCE_MODE_REDIRECT_URL = None
