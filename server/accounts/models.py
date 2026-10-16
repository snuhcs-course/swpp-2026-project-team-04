"""User accounts: a login id, a nickname, and a bcrypt password hash."""

from django.contrib.auth.base_user import AbstractBaseUser, BaseUserManager
from django.db import models


class UserManager(BaseUserManager):
    def create_user(self, login_id, nickname, password):
        user = self.model(login_id=login_id, nickname=nickname)
        user.set_password(password)
        user.save(using=self._db)
        return user


class User(AbstractBaseUser):
    # Lowercase letters, digits, and "_", 4 to 20 long (checked on sign-up).
    login_id = models.CharField(max_length=20, unique=True)
    nickname = models.CharField(max_length=12)
    created_at = models.DateTimeField(auto_now_add=True)

    USERNAME_FIELD = "login_id"
    REQUIRED_FIELDS = ["nickname"]

    objects = UserManager()

    def __str__(self):
        return self.login_id
