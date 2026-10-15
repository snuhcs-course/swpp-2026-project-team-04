from django.urls import path

from .views import MatchListView

urlpatterns = [path("", MatchListView.as_view())]
