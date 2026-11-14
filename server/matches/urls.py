from django.urls import path

from .views import FeedbackUploadView, MatchFeedbackView, MatchListView, MatchStatsView

urlpatterns = [
    path("", MatchListView.as_view()),
    path("/stats", MatchStatsView.as_view()),
    path("/<int:match_id>/feedback", MatchFeedbackView.as_view()),
    path("/feedback/<str:client_id>", FeedbackUploadView.as_view()),
]
