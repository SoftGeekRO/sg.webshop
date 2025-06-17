import threading

_thread_locals = threading.local()


def set_request(request):
    _thread_locals.request = request
    _thread_locals.preloads = []


def get_request():
    return getattr(_thread_locals, "request", None)


def add_preload(tag):
    if hasattr(_thread_locals, "preloads"):
        if tag not in _thread_locals.preloads:
            _thread_locals.preloads.append(tag)


def get_preload_list():
    return getattr(_thread_locals, "preloads", [])


def clear_request():
    _thread_locals.request = None
    _thread_locals.preloads = []
