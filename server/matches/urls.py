from django.urls import path

from .rankings import WeeklyRankingView
from .views import FeedbackUploadView, MatchFeedbackView, MatchListView, MatchStatsView

urlpatterns = [
    path("", MatchListView.as_view()),
    path("/stats", MatchStatsView.as_view()),
    path("/rankings/weekly", WeeklyRankingView.as_view()),
    path("/<int:match_id>/feedback", MatchFeedbackView.as_view()),
    path("/feedback/<str:client_id>", FeedbackUploadView.as_view()),
]
