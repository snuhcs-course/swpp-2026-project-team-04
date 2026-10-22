# AI-generated with Claude Code (Opus 5.5), 2026-10-21, reviewed by Jinyoung Park
from django.urls import path

from .internal import BattleRecoverView, BattleStartView, BattleVoidView, ResultSaveView

urlpatterns = [
    path("results", ResultSaveView.as_view()),
    path("battles/start", BattleStartView.as_view()),
    path("battles/void", BattleVoidView.as_view()),
    path("battles/recover", BattleRecoverView.as_view()),
]
