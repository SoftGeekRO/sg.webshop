from django.urls import path, include

from .views import index

app_name = "frontpage"
urlpatterns = [
    path("", index, name="index"),
]
