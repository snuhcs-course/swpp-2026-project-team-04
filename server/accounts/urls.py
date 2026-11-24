from django.urls import path

from .views import GoogleLoginView, LoginView, SignUpView

urlpatterns = [
    path("signup", SignUpView.as_view()),
    path("login", LoginView.as_view()),
    path("google", GoogleLoginView.as_view()),
]
