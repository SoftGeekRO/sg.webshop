import logging
import threading

from django.core.cache import cache

logger = logging.getLogger("django")

_thread_locals = threading.local()
_storage = threading.local()


def set_current_request(request):
    _thread_locals.request = request


def get_current_request():
    return getattr(_thread_locals, "request", None)


def get_precache_key():
    request = get_current_request()
    if not request:
        return None
    domain = request.get_host().lower()
    return f"preload_cache::{domain}"


def get_storage():
    if not hasattr(_storage, "preloads"):
        _storage.preloads = set()
    return _storage.preloads


def add_preload(link_tag: str):
    get_storage().add(link_tag)


def get_preloads():
    return sorted(get_storage())  # deterministic output


def clear_preloads():
    if hasattr(_storage, "preloads"):
        _storage.preloads.clear()
