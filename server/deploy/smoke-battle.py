"""Read-only deployment smoke test. Run with existing Django environment.

Uses at most two existing accounts; never creates users or writes match history.
Short-lived access tokens stay in process memory and are never printed.
"""
import base64
import hashlib
import json
import os
import socket
import struct
import sys
import time
import uuid
from datetime import timedelta

sys.path.insert(0, "/srv/gymrats/backend")
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "gymrats.settings")
import django

django.setup()
from django.contrib.auth import get_user_model
from rest_framework_simplejwt.tokens import AccessToken


class Client:
    def __init__(self, token):
        self.sock = socket.create_connection(("127.0.0.1", 8080), timeout=5)
        key = base64.b64encode(os.urandom(16)).decode()
        header = (
            "GET /ws/v1/battle HTTP/1.1\r\nHost: localhost\r\n"
            "Upgrade: websocket\r\nConnection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n"
            f"Authorization: Bearer {token}\r\n\r\n"
        )
        self.sock.sendall(header.encode())
        self.buffer = b""
        while b"\r\n\r\n" not in self.buffer:
            self.buffer += self.sock.recv(4096)
        response, self.buffer = self.buffer.split(b"\r\n\r\n", 1)
        self.accepted = response.startswith(b"HTTP/1.1 101")
        if self.accepted:
            expected = base64.b64encode(hashlib.sha1((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest())
            assert expected.lower() in response.lower()
        self.seq = 0
        self.prefix = uuid.uuid4().hex
        self.match = None

    def take(self, count):
        while len(self.buffer) < count:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise RuntimeError("socket closed")
            self.buffer += chunk
        data, self.buffer = self.buffer[:count], self.buffer[count:]
        return data

    def send(self, kind, payload):
        self.seq += 1
        data = {"v": 1, "type": kind, "request_id": f"smoke-{self.prefix}-{self.seq}", "payload": payload}
        if self.match:
            data["match_id"] = self.match
        raw = json.dumps(data).encode()
        mask = os.urandom(4)
        size = len(raw)
        frame = bytes([0x81, 0x80 | size]) if size < 126 else bytes([0x81, 0xFE]) + struct.pack("!H", size)
        self.sock.sendall(frame + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(raw)))

    def next(self, wanted):
        for _ in range(30):
            a, b = self.take(2)
            size = b & 127
            if size == 126:
                size = struct.unpack("!H", self.take(2))[0]
            elif size == 127:
                size = struct.unpack("!Q", self.take(8))[0]
            raw = self.take(size)
            if a & 15 != 1:
                continue
            event = json.loads(raw)
            if event["type"] == "error":
                raise RuntimeError("server rejected smoke request")
            if event["type"] == wanted:
                return event
        raise RuntimeError("expected event not received")

    def close(self):
        self.sock.close()


invalid = Client("invalid-smoke-token")
assert not invalid.accepted
invalid.close()
print("PASS invalid token rejected")
users = list(get_user_model().objects.order_by("id")[:2])
if len(users) < 2:
    print("SKIP two-player test: fewer than two existing accounts (no users created)")
    sys.exit(0)
clients = []
try:
    for user in users:
        token = AccessToken.for_user(user)
        token.set_exp(lifetime=timedelta(seconds=60))
        client = Client(str(token))
        clients.append(client)
        assert client.accepted
        client.next("session.welcome")
    print("PASS existing Django JWT accepted")
    a, b = clients
    # Reverse connection order deliberately; FIFO is queue arrival order.
    for client in (b, a):
        client.send("queue.join", {"exercise": "push_up", "avatar_id": "avatar_02"})
        client.next("queue.joined")
    found_b, found_a = b.next("match.found"), a.next("match.found")
    assert found_a["match_id"] == found_b["match_id"]
    assert [p["player_id"] for p in found_b["payload"]["players"]] == [str(users[1].pk), str(users[0].pk)]
    print("PASS deployed FIFO matching order and roster")
    for client in clients:
        client.match = found_a["match_id"]
        client.send("match.ready", {"ready": True})
    start_a, start_b = a.next("match.start"), b.next("match.start")
    assert start_a["payload"] == start_b["payload"]
    print("PASS synchronized start")
    time.sleep(3.1)
    a.send("match.leave", {"reason": "user_exit"})
    result_a, result_b = a.next("match.finished"), b.next("match.finished")
    assert result_a["match_id"] == result_b["match_id"]
    print("PASS deployed match termination")
finally:
    for client in clients:
        client.close()
