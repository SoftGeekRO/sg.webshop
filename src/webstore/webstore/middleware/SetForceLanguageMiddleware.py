from django.utils import translation


class SetForceLanguageMiddleware:
    def __init__(self, get_response):
        translation.activate("ro_RO")
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)
        translation.deactivate()
        return response
