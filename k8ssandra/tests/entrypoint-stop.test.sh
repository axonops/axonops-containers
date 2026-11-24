#!/usr/bin/env bash
#
# Stop-path test for k8ssandra/<line>/axonops-entrypoint.sh.
#
# Runs the real entrypoint with stand-ins for the Management API, Cassandra and
# axon-agent (no Docker, no root, no network) and checks what a container stop
# does to them:
#
#   - the stand-in Cassandra receives the stop signal and finishes its shutdown
#     before the entrypoint exits. In a container, the entrypoint exiting ends
#     the container and the kernel SIGKILLs whatever is still running, so a
#     shutdown still in progress at that point is cut off;
#   - axon-agent is stopped and not restarted by its supervisor;
#   - the entrypoint exits with the main process's own status;
#   - nothing is left running.
#
# Two ways a stop signal arrives are covered:
#
#   group   the image's inherited ENTRYPOINT is `tini -g`, which sends the
#           signal to the entrypoint's whole process group (Kubernetes pods,
#           plain `docker stop`);
#   direct  only the entrypoint receives it: `docker run --entrypoint`, a
#           Kubernetes `command:` override or any runtime without `tini -g`.
#
# Linux only (it reads /proc). Usage:
#   k8ssandra/tests/entrypoint-stop.test.sh [path/to/axonops-entrypoint.sh]
# Without an argument it tests k8ssandra/5.0/axonops-entrypoint.sh and checks
# that the 4.0 and 4.1 copies are identical to it.

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8SSANDRA_DIR="$(cd "$HERE/.." && pwd)"
ENTRYPOINT="${1:-$K8SSANDRA_DIR/5.0/axonops-entrypoint.sh}"

if [ "$(uname -s)" != "Linux" ]; then
  echo "SKIP: this test reads /proc and runs on Linux only"
  exit 0
fi
command -v python3 >/dev/null 2>&1 || { echo "FAIL: python3 is needed to create the stand-in agent socket"; exit 1; }

# Job control: every background job gets its own process group, as the
# entrypoint does under tini or as PID 1, so a group signal reaches only it.
set -m

FAILURES=0
pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; FAILURES=$((FAILURES + 1)); }

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/k8ssandra-stop.XXXXXX")"
cleanup() { rm -rf "$ROOT"; }
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Stand-ins
# ---------------------------------------------------------------------------
make_stubs() {
  local t="$1"
  mkdir -p "$t/bin" "$t/cassandra/bin" "$t/cassandra/conf" "$t/mgmt" "$t/state"

  # A JVM: records its pid, runs until signalled, then takes
  # STUB_<NAME>_SHUTDOWN_SECONDS to shut down. The Management API stand-in
  # starts Cassandra as a daemon, the way `cassandra -R` is started by it.
  cat > "$t/bin/stub-jvm" <<'EOF'
#!/usr/bin/env bash
name="$1"; dir="$STUB_STATE"
echo "$$" > "$dir/$name.pid"
echo "started" >> "$dir/$name.log"
shutdown_var="STUB_${name^^}_SHUTDOWN_SECONDS"; shutdown_seconds="${!shutdown_var:-1}"
term_var="STUB_${name^^}_TERM_STATUS"; term_status="${!term_var:-143}"
stop() {
  echo "shutdown started" >> "$dir/$name.log"
  sleep "$shutdown_seconds"
  echo "shut down cleanly" >> "$dir/$name.log"
  exit "$term_status"
}
trap stop TERM
trap stop INT
if [ "$name" = "mgmtapi" ]; then
  ( "$STUB_BIN/stub-jvm" cassandra & )
fi
while :; do
  if [ -f "$dir/$name.exit" ]; then
    echo "exited on its own" >> "$dir/$name.log"
    exit "$(cat "$dir/$name.exit")"
  fi
  sleep 0.1 & wait $!
done
EOF

  # Standalone image: bin/cassandra -f execs the JVM.
  cat > "$t/cassandra/bin/cassandra" <<'EOF'
#!/usr/bin/env bash
exec "$STUB_BIN/stub-jvm" cassandra
EOF

  # Upstream /docker-entrypoint.sh mgmtapi: a bash that runs the Management
  # API JVM in the foreground (it does not exec it).
  cat > "$t/bin/mgmt-entrypoint" <<'EOF'
#!/usr/bin/env bash
"$STUB_BIN/stub-jvm" mgmtapi
EOF

  cat > "$t/bin/axon-agent" <<'EOF'
#!/usr/bin/env bash
dir="$STUB_STATE"
echo "$$" >> "$dir/agent.pids"
echo "started" >> "$dir/agent.log"
trap 'echo "stopped" >> "$dir/agent.log"; exit 0' TERM
if [ -n "${STUB_AGENT_CRASH_ONCE:-}" ] && [ ! -e "$dir/agent.crashed" ]; then
  touch "$dir/agent.crashed"
  exit 7
fi
while :; do sleep 0.1 & wait $!; done
EOF

  printf '#!/bin/sh\nexit 0\n' > "$t/bin/java"
  # The CQL port is reported open once the state/ready file exists.
  cat > "$t/bin/ss" <<'EOF'
#!/bin/sh
[ -f "$STUB_STATE/ready" ] && echo "tcp   LISTEN 0      128    0.0.0.0:9042   0.0.0.0:*"
exit 0
EOF
  chmod 755 "$t/bin/"* "$t/cassandra/bin/cassandra"

  printf 'seed_provider:\n  - seeds: "127.0.0.1"\nnative_transport_port: 9042\n' > "$t/cassandra/conf/cassandra.yaml"
  printf 'dc=dc1\nrack=rack1\n' > "$t/cassandra/conf/cassandra-rackdc.properties"
  python3 -c 'import socket,sys; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1])' "$t/state/agent.socket"
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Live (non-zombie) processes in process group $1.
group_members() {
  local pgid="$1" stat rest state ppid pgrp p
  for p in /proc/[0-9]*; do
    read -r stat 2>/dev/null < "$p/stat" || continue
    rest="${stat##*) }"
    read -r state ppid pgrp _ <<< "$rest"
    [ "$pgrp" = "$pgid" ] && [ "$state" != "Z" ] && echo "${p#/proc/}"
  done
}

wait_for() { # wait_for <seconds> <command...>
  local deadline=$(( $(date +%s) + $1 )); shift
  until "$@"; do
    [ "$(date +%s)" -ge "$deadline" ] && return 1
    sleep 0.1
  done
}

has_line() { [ -f "$1" ] && grep -qx "$2" "$1"; }
count_lines() { if [ -f "$1" ]; then grep -cx "$2" "$1"; else echo 0; fi; }

# Starts the entrypoint in its own process group. Sets EP_PID, T (the stub
# root) and EP_OUT. Mode: standalone (no Management API) or mgmtapi.
start_entrypoint() {
  local mode="$1"; shift
  T="$(mktemp -d "$ROOT/run.XXXXXX")"
  make_stubs "$T"
  EP_OUT="$T/entrypoint.out"
  local maac="$T/no-mgmt"
  if [ "$mode" = "mgmtapi" ]; then
    maac="$T/mgmt"
    touch "$T/mgmt/datastax-mgmtapi-server.jar"
  fi
  env "$@" \
    PATH="$T/bin:$PATH" \
    STUB_BIN="$T/bin" STUB_STATE="$T/state" \
    MAAC_PATH="$maac" \
    MGMT_API_ENTRYPOINT="$T/bin/mgmt-entrypoint" \
    CASSANDRA_HOME="$T/cassandra" \
    CASSANDRA_LISTEN_ADDRESS=127.0.0.1 \
    AXON_AGENT_BIN="$T/bin/axon-agent" \
    AXON_AGENT_LOG="$T/state/axon-agent.log" \
    AXONOPS_SOCKET_FILE="$T/state/agent.socket" \
    AXONOPS_READY_POLL_SECONDS=0.2 \
    AXON_AGENT_ORG=test AXON_AGENT_NTP_HOST=127.0.0.1 \
    bash "$ENTRYPOINT" > "$EP_OUT" 2>&1 &
  EP_PID=$!
}

# Waits up to $1 seconds for the entrypoint to exit; sets EP_STATUS (or
# EP_STATUS=timeout) and EP_LEFT (processes still in its group right after).
finish_entrypoint() {
  local deadline=$(( $(date +%s) + $1 ))
  while kill -0 "$EP_PID" 2>/dev/null; do
    if [ "$(date +%s)" -ge "$deadline" ]; then
      EP_STATUS=timeout
      break
    fi
    sleep 0.05
  done
  if [ "${EP_STATUS:-}" != "timeout" ]; then
    wait "$EP_PID" 2>/dev/null
    EP_STATUS=$?
  fi
  # Snapshot what the entrypoint left behind (in a container: what the kernel
  # would SIGKILL), then clean it up.
  CASSANDRA_DONE_AT_EXIT=no
  has_line "$T/state/cassandra.log" "shut down cleanly" && CASSANDRA_DONE_AT_EXIT=yes
  EP_LEFT="$(group_members "$EP_PID" | tr '\n' ' ')"
  kill -KILL -- "-$EP_PID" 2>/dev/null
  local f
  for f in "$T/state/"*.pid; do [ -f "$f" ] && kill -KILL "$(cat "$f")" 2>/dev/null; done
  [ -f "$T/state/agent.pids" ] && while read -r p; do kill -KILL "$p" 2>/dev/null; done < "$T/state/agent.pids"
  return 0
}

send_signal() { # send_signal <group|direct> <SIG>
  if [ "$1" = "group" ]; then kill -s "$2" -- "-$EP_PID"; else kill -s "$2" "$EP_PID"; fi
}

agent_running() { has_line "$T/state/agent.log" "started"; }
agent_restarted() { [ "$(count_lines "$T/state/agent.log" started)" -ge 2 ]; }
main_running() { [ -f "$T/state/cassandra.pid" ]; }

# ---------------------------------------------------------------------------
# Scenarios
# ---------------------------------------------------------------------------

# Stop a fully started container and check the clean-shutdown contract.
check_stop() { # check_stop <standalone|mgmtapi> <group|direct> <SIG>
  local mode="$1" how="$2" sig="$3" label
  if [ "$how" = "group" ]; then label="$mode, SIG$sig to the process group"; else label="$mode, SIG$sig to the entrypoint only"; fi
  EP_STATUS=""
  start_entrypoint "$mode"
  touch "$T/state/ready"
  if ! wait_for 15 agent_running; then
    fail "$label: axon-agent never started; output: $(tail -5 "$EP_OUT" | tr '\n' ' ')"
    finish_entrypoint 1
    return
  fi
  send_signal "$how" "$sig"
  finish_entrypoint 15

  if [ "$CASSANDRA_DONE_AT_EXIT" = yes ]; then
    pass "$label: Cassandra shut down cleanly before the entrypoint exited"
  else
    fail "$label: the entrypoint exited (status $EP_STATUS) before Cassandra shut down; cassandra.log: $(tr '\n' '|' < "$T/state/cassandra.log")"
  fi
  if [ "$mode" = "mgmtapi" ]; then
    if has_line "$T/state/mgmtapi.log" "shut down cleanly"; then
      pass "$label: the Management API received the signal"
    else
      fail "$label: the Management API never received the signal; mgmtapi.log: $(tr '\n' '|' < "$T/state/mgmtapi.log")"
    fi
  fi
  if has_line "$T/state/agent.log" "stopped" && [ "$(count_lines "$T/state/agent.log" started)" -eq 1 ]; then
    pass "$label: axon-agent stopped and was not restarted"
  else
    fail "$label: axon-agent not stopped once; agent.log: $(tr '\n' '|' < "$T/state/agent.log")"
  fi
  if [ "$EP_STATUS" = "143" ]; then
    pass "$label: the entrypoint exits 143, the main process's status"
  else
    fail "$label: the entrypoint status is $EP_STATUS, want 143"
  fi
  if [ -z "$EP_LEFT" ]; then
    pass "$label: nothing left running"
  else
    fail "$label: still running after the entrypoint exited: $EP_LEFT"
  fi
}

# A stop signal while Cassandra is still starting: no agent, clean stop.
check_stop_during_startup() {
  local label="standalone, SIGTERM during startup"
  EP_STATUS=""
  start_entrypoint standalone
  if ! wait_for 15 main_running; then
    fail "$label: Cassandra never started"
    finish_entrypoint 1
    return
  fi
  send_signal direct TERM
  finish_entrypoint 15
  if [ "$CASSANDRA_DONE_AT_EXIT" = yes ] && [ "$EP_STATUS" = "143" ] && [ ! -f "$T/state/agent.log" ] && [ -z "$EP_LEFT" ]; then
    pass "$label: Cassandra shut down cleanly, axon-agent never started, status 143"
  else
    fail "$label: cassandra done=$CASSANDRA_DONE_AT_EXIT status=$EP_STATUS agent.log=$( [ -f "$T/state/agent.log" ] && tr '\n' '|' < "$T/state/agent.log") left=[$EP_LEFT]"
  fi
}

# Cassandra exiting on its own still ends the container with its status, and
# takes the agent supervisor down with it.
check_main_exits_on_its_own() {
  local label="standalone, Cassandra exits on its own with status 3"
  EP_STATUS=""
  start_entrypoint standalone
  touch "$T/state/ready"
  if ! wait_for 15 agent_running; then
    fail "$label: axon-agent never started"
    finish_entrypoint 1
    return
  fi
  echo 3 > "$T/state/cassandra.exit"
  finish_entrypoint 15
  if [ "$EP_STATUS" = "3" ] && [ -z "$EP_LEFT" ]; then
    pass "$label: the entrypoint exits 3 and nothing is left running"
  else
    fail "$label: status=$EP_STATUS left=[$EP_LEFT]"
  fi
}

# The supervisor still restarts a crashed agent, and still stops it on SIGTERM.
check_agent_restart_then_stop() {
  local label="standalone, axon-agent crash"
  EP_STATUS=""
  start_entrypoint standalone STUB_AGENT_CRASH_ONCE=1
  touch "$T/state/ready"
  # The supervisor waits 2s before a restart.
  wait_for 15 agent_restarted
  if agent_restarted; then
    pass "$label: the supervisor restarted axon-agent"
  else
    fail "$label: axon-agent was not restarted; agent.log: $(tr '\n' '|' < "$T/state/agent.log" 2>/dev/null)"
  fi
  send_signal direct TERM
  finish_entrypoint 15
  if has_line "$T/state/agent.log" "stopped" && [ "$(count_lines "$T/state/agent.log" started)" -eq 2 ] && [ -z "$EP_LEFT" ]; then
    pass "$label: after a restart, SIGTERM still stops axon-agent for good"
  else
    fail "$label: agent.log: $(tr '\n' '|' < "$T/state/agent.log") left=[$EP_LEFT]"
  fi
}

# A main process that exits the instant it is signalled: the entrypoint must
# report its own status (0 here), not the 143 of the interrupted wait.
check_status_race() {
  local runs=10 bad=0 n
  for n in $(seq 1 "$runs"); do
    EP_STATUS=""
    start_entrypoint standalone STUB_CASSANDRA_SHUTDOWN_SECONDS=0 STUB_CASSANDRA_TERM_STATUS=0
    touch "$T/state/ready"
    wait_for 15 agent_running || { bad=$((bad + 1)); finish_entrypoint 1; continue; }
    send_signal direct TERM
    finish_entrypoint 15
    [ "$EP_STATUS" = "0" ] || bad=$((bad + 1))
  done
  if [ "$bad" -eq 0 ]; then
    pass "a main process that exits at once on SIGTERM: its own status is reported ($runs runs)"
  else
    fail "$bad of $runs runs reported a status other than the main process's 0"
  fi
}

check_copies_identical() {
  local line
  for line in 4.0 4.1; do
    if cmp -s "$K8SSANDRA_DIR/5.0/axonops-entrypoint.sh" "$K8SSANDRA_DIR/$line/axonops-entrypoint.sh"; then
      pass "k8ssandra/$line/axonops-entrypoint.sh is identical to 5.0"
    else
      fail "k8ssandra/$line/axonops-entrypoint.sh differs from 5.0"
    fi
  done
}

echo "Testing $ENTRYPOINT"
for mode in standalone mgmtapi; do
  for how in group direct; do
    check_stop "$mode" "$how" TERM
  done
done
check_stop standalone direct INT
check_stop mgmtapi direct INT
check_stop_during_startup
check_main_exits_on_its_own
check_agent_restart_then_stop
check_status_race
[ $# -eq 0 ] && check_copies_identical

if [ "$FAILURES" -eq 0 ]; then
  echo "all checks passed"
  exit 0
fi
echo "$FAILURES check(s) failed"
exit 1
