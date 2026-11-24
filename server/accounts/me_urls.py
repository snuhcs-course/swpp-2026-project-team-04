from django.urls import path

from .views import BodyInfoView, MeView

urlpatterns = [
    path("me", MeView.as_view()),
    path("me/body", BodyInfoView.as_view()),
]
