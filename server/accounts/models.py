"""User accounts: a login id, a nickname, and a bcrypt password hash.

Google accounts get a generated login id and no usable password; they log
in again with Google. Height and weight are optional
and kept only with the user's consent.
"""

import secrets

from django.contrib.auth.base_user import AbstractBaseUser, BaseUserManager
from django.db import models


class UserManager(BaseUserManager):
    def create_user(self, login_id, nickname, password):
        user = self.model(login_id=login_id, nickname=nickname)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_social_user(self, provider, subject, nickname):
        """A new account for a Google identity. [provider] is the field that
        stores it: "google_sub"."""
        prefix = {"google_sub": "g_"}[provider]
        user = self.model(
            login_id=prefix + secrets.token_hex(6),
            nickname=nickname,
            **{provider: subject},
        )
        user.set_unusable_password()
        user.save(using=self._db)
        return user


class User(AbstractBaseUser):
    # Lowercase letters, digits, and "_", 4 to 20 long (checked on sign-up).
    login_id = models.CharField(max_length=20, unique=True)
    nickname = models.CharField(max_length=12)
    created_at = models.DateTimeField(auto_now_add=True)
    # The provider's stable account id; null for id-and-password accounts.
    google_sub = models.CharField(max_length=255, unique=True, null=True, blank=True)
    # Optional, for more accurate form feedback; set only with consent.
    height_cm = models.FloatField(null=True, blank=True)
    weight_kg = models.FloatField(null=True, blank=True)
    body_consent_at = models.DateTimeField(null=True, blank=True)

    USERNAME_FIELD = "login_id"
    REQUIRED_FIELDS = ["nickname"]

    objects = UserManager()

    def __str__(self):
        return self.login_id
