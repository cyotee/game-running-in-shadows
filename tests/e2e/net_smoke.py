#!/usr/bin/env python3
"""Two-instance netcode smoke test.

Launches a host and a client of net_test.tscn with simulated latency,
drives the client's player via the MCP TCP protocol, and asserts the
server sees the client's movement and glide state.

Usage: python3 tests/e2e/net_smoke.py  (from the repo root)
"""
import json
import os
import signal
import socket
import subprocess
import sys
import time

GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
SCENE = "res://scenes/dev/net_test.tscn"
LATENCY_MS = os.environ.get("NET_TEST_LATENCY_MS", "50")
HOST_MCP, CLIENT_MCP, CLIENT2_MCP = 9191, 9192, 9193


class Instance:
    def __init__(self, mcp_port: int):
        env = os.environ.copy()
        env.update({
            "GODOT_MCP_PORT": str(mcp_port),
            "NET_TEST_LATENCY_MS": LATENCY_MS,
            # NetworkSimulator self-disables when these are non-empty:
            "CI": "", "NETFOX_CI": "", "NETFOX_NO_AUTOCONNECT": "",
        })
        self.proc = subprocess.Popen(
            [GODOT, "--headless", "--path", ".", SCENE],
            env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.sock = None
        self.reader = None
        self._id = 0
        deadline = time.time() + 20
        while time.time() < deadline:
            try:
                self.sock = socket.create_connection(("127.0.0.1", mcp_port), timeout=2)
                self.reader = self.sock.makefile("r")
                return
            except OSError:
                time.sleep(0.5)
        raise RuntimeError(f"MCP port {mcp_port} never came up")

    def cmd(self, command: str, params: dict | None = None) -> dict:
        self._id += 1
        msg = {"id": self._id, "command": command, "params": params or {}}
        self.sock.sendall((json.dumps(msg) + "\n").encode())
        return json.loads(self.reader.readline())

    def action(self, action: str, pressed: bool) -> dict:
        # Raw Input.action_press/_release: robust across frame timing, unlike
        # key events whose press+release can collapse into one buffered flush.
        return self.cmd("key_press", {"action": action, "pressed": pressed})

    def stop(self):
        try:
            if self.sock:
                self.sock.close()
        finally:
            self.proc.send_signal(signal.SIGTERM)
            try:
                # Wait for the UDP ports to actually free up so back-to-back
                # runs don't join a dying host.
                self.proc.wait(timeout=8)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait(timeout=5)


def wait_for(fn, timeout=15.0, interval=0.5, desc="condition"):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if fn():
            return
        time.sleep(interval)
    raise AssertionError(f"Timed out waiting for {desc}")


def main() -> int:
    host = Instance(HOST_MCP)
    client = Instance(CLIENT_MCP)
    try:
        # Both instances must end up with a player node for peer 1 and the
        # client's peer id. Discover the client's peer id from the client.
        wait_for(lambda: client.cmd("eval", {"code": "return multiplayer.get_unique_id()"})
                 .get("result", 1) not in (1, 0), desc="client to get a peer id")
        peer_id = client.cmd("eval", {"code": "return multiplayer.get_unique_id()"})["result"]
        print(f"client peer id: {peer_id}")

        path = f"/root/NetTest/Players/{int(peer_id)}"
        wait_for(lambda: host.cmd("get_property", {"node_path": path, "property": "name"})
                 .get("success", False), desc="host to spawn client player")
        print("host spawned client player")

        # Drive the client forward; its input must replicate through the
        # latency proxy and move the server-side body.
        start = host.cmd("eval", {"code": f"return get_node('{path}').global_position.z"})["result"]
        client.action("move_forward", True)
        wait_for(lambda: abs(host.cmd("eval", {"code": f"return get_node('{path}').global_position.z"})
                 ["result"] - start) > 0.5, desc="server-side movement from client input")
        client.action("move_forward", False)
        print("movement replicated to host")

        # Glide from the client (needs to be airborne: jump first). The
        # jump/glide timing can race the landing, so retry the whole cycle.
        def try_glide() -> bool:
            client.action("jump", True)
            time.sleep(0.2)
            client.action("jump", False)
            time.sleep(0.35)  # mid-air
            client.action("glide", True)
            time.sleep(0.3)
            client.action("glide", False)
            deadline = time.time() + 2.0
            while time.time() < deadline:
                if host.cmd("get_property", {"node_path": path, "property": "is_gliding"}) \
                        .get("value", False):
                    return True
                time.sleep(0.25)
            return False

        wait_for(try_glide, timeout=20, interval=0.5, desc="glide state on host")
        print("glide replicated to host")

        # Third peer joins: host must end up with three player bodies
        # (multi-peer spawn smoke for the sessions milestone).
        client2 = Instance(CLIENT2_MCP)
        try:
            wait_for(lambda: host.cmd(
                "eval", {"code": "return get_tree().get_nodes_in_group('players').size()"})
                .get("result", 0) >= 3, desc="three player bodies on host")
            print("three peers spawned on host")
        finally:
            client2.stop()

        print("E2E NET SMOKE: PASS")
        return 0
    finally:
        host.stop()
        client.stop()


if __name__ == "__main__":
    sys.exit(main())
