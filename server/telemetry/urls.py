from django.urls import path

from .views import EventBatchView

urlpatterns = [
    path("events", EventBatchView.as_view()),
]
