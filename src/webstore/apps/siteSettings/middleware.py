class SEOMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)
        if hasattr(response, "context_data"):
            response.context_data.setdefault("seo", {})
        return response
