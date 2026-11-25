from django.urls import path

from .friends_views import (
    FriendInviteActionView,
    FriendInvitesView,
    FriendInviteView,
    FriendRequestAnswerView,
    FriendRequestsView,
    FriendsView,
)

urlpatterns = [
    path("", FriendsView.as_view()),
    path("/requests", FriendRequestsView.as_view()),
    path("/requests/<int:request_id>/accept", FriendRequestAnswerView.as_view()),
    path(
        "/requests/<int:request_id>/decline",
        FriendRequestAnswerView.as_view(accept=False),
    ),
    path("/invites", FriendInvitesView.as_view()),
    path("/invites/<int:invite_id>", FriendInviteView.as_view()),
    path("/invites/<int:invite_id>/accept", FriendInviteActionView.as_view()),
    path(
        "/invites/<int:invite_id>/decline",
        FriendInviteActionView.as_view(action="decline"),
    ),
    path(
        "/invites/<int:invite_id>/cancel",
        FriendInviteActionView.as_view(action="cancel"),
    ),
]
