from webstore.threadlocals import set_current_request

class ThreadLocalMiddleware:
    """
    Middleware that stores the current HTTP request in thread-local storage.

    This is useful when you need access to the current request in parts of the code
    that do not receive it explicitly (e.g. in template tags, utility functions,
    or signal handlers). To retrieve the request, use a `get_current_request()`
    function implemented in the same `threadlocals` module.

    This pattern should be used with care, as excessive use of thread-locals can
    make code harder to debug and test.
    """

    def __init__(self, get_response):
        """
        One-time configuration and initialization.

        Args:
            get_response (callable): The next middleware or view function.
        """
        self.get_response = get_response

    def __call__(self, request):
        """
        Called for each request before the view (and later middleware) is called.

        Stores the request in thread-local storage to make it globally accessible
        for the current request's lifecycle.

        Args:
            request (HttpRequest): The incoming HTTP request object.

        Returns:
            HttpResponse: The response returned by the view or subsequent middleware.
        """
        set_current_request(request)
        return self.get_response(request)
