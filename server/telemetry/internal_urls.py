from django.urls import path

from .views import BattleFinishedView

# Battle server only; nginx does not forward /api/internal/.
urlpatterns = [
    path("battle", BattleFinishedView.as_view()),
]
