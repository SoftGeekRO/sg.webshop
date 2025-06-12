import platform

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = "django-insecure-)6k7$qfidx0_owrbzpn1!1#l&ou=%2w=3w#9@d&v4$tf^82$bk"

ALLOWED_HOSTS = [
    "softgeek.ro",
    "www.softgeek.ro",
    "progeek.ro",
    "www.progeek.ro",
    "localhost",
]

# Password validation
# https://docs.djangoproject.com/en/5.2/ref/settings/#auth-password-validators

AUTH_PASSWORD_VALIDATORS = [
    {
        "NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.CommonPasswordValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.NumericPasswordValidator",
    },
]

# Django authentication system
# https://docs.djangoproject.com/en/2.2/topics/auth/

AUTHENTICATION_BACKENDS = ("django.contrib.auth.backends.ModelBackend",)

BCryptHasher = [
    "django.contrib.auth.hashers.BCryptSHA256PasswordHasher",
    "django.contrib.auth.hashers.BCryptPasswordHasher",
]

PASSWORD_HASHERS = [
    "django.contrib.auth.hashers.PBKDF2PasswordHasher",
    "django.contrib.auth.hashers.PBKDF2SHA1PasswordHasher",
    "django.contrib.auth.hashers.Argon2PasswordHasher",
]

# fix for the DEV when the arhitecture is not x86_64 and the ARM processors can't work with this lib
if "x86_64" in platform.uname().machine:
    PASSWORD_HASHERS = BCryptHasher + PASSWORD_HASHERS
