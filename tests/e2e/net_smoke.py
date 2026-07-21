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
        deadline = time.time() + 45
        while time.time() < deadline:
            try:
                self.sock = socket.create_connection(("127.0.0.1", mcp_port), timeout=3)
                self.sock.settimeout(15)
                self.reader = self.sock.makefile("r")
                return
            except OSError:
                time.sleep(0.5)
        raise RuntimeError(f"MCP port {mcp_port} never came up")

    def cmd(self, command: str, params: dict | None = None) -> dict:
        self._id += 1
        msg = {"id": self._id, "command": command, "params": params or {}}
        self.sock.sendall((json.dumps(msg) + "\n").encode())
        line = self.reader.readline()
        if not line:
            raise RuntimeError(f"MCP {command}: empty response (peer closed)")
        return json.loads(line)

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

        # A spawned player node appears before the netfox tick clocks between
        # the two instances have finished syncing. Driving input before the
        # clocks settle drops the first inputs (they map to already-simulated
        # ticks), so wait for the sync to stabilise — longer under machine load.
        time.sleep(10)

        # Drive the client forward; its input must replicate through the
        # latency proxy and move the server-side body. Retry the whole
        # press/observe cycle so a dropped first input just re-sends.
        def try_move() -> bool:
            start = host.cmd("eval", {"code": f"return get_node('{path}').global_position.z"}).get("result")
            client.action("move_forward", True)
            deadline = time.time() + 5.0
            moved = False
            while time.time() < deadline:
                now = host.cmd("eval", {"code": f"return get_node('{path}').global_position.z"}).get("result")
                if start is not None and now is not None and abs(float(now) - float(start)) > 0.25:
                    moved = True
                    break
                time.sleep(0.25)
            client.action("move_forward", False)
            return moved

        wait_for(try_move, timeout=40, interval=0.75, desc="server-side movement from client input")
        print("movement replicated to host")

        # Ability-input replication: a Repulse press spends 2 Resonance, and
        # that drop persists on the host's authoritative copy of the client's
        # player. (Glide would self-cancel the next grounded tick, giving no
        # stable state to observe — Repulse's Resonance spend is durable.)
        res_code = f"return get_node('{path}/Resonance').current"

        def try_repulse() -> bool:
            before = host.cmd("eval", {"code": res_code}).get("result")
            client.action("repulse", True)
            time.sleep(0.15)
            client.action("repulse", False)
            deadline = time.time() + 1.5
            while time.time() < deadline:
                after = host.cmd("eval", {"code": res_code}).get("result")
                if before is not None and after is not None and after < before - 1.0:
                    return True
                time.sleep(0.2)
            return False

        wait_for(try_repulse, timeout=20, interval=0.5, desc="repulse spend on host")
        print("ability input replicated to host")

        # Ping replication: the client tags the host's player (peer 1) as an
        # enemy. Pings are host-authoritative RPC OUTSIDE the rollback path, so
        # the request lands on the host, which must resolve latest_enemy_tag for
        # the client to the tagged peer. This is the hook Familiar consumes.
        def try_ping() -> bool:
            client.cmd("eval", {"code":
                "var ps = get_node('/root/PingService'); "
                "ps.request_ping(ps.ENEMY, Vector3.ZERO, 1); return true"})
            deadline = time.time() + 2.0
            while time.time() < deadline:
                tag = host.cmd("eval", {"code":
                    "return get_node('/root/PingService').latest_enemy_tag("
                    f"{int(peer_id)})"}).get("result")
                if tag == 1:
                    return True
                time.sleep(0.2)
            return False

        wait_for(try_ping, timeout=20, interval=0.5, desc="enemy-tag ping replicated to host")
        print("enemy-tag ping replicated to host")

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
