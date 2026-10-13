#!/usr/bin/env bash
# Stop the brainstorm server and clean up
# Usage: stop-server.sh <session_dir>
#
# Kills the server process. Only deletes session directory if it's
# under /tmp (ephemeral). Persistent directories (.hyperpowers/) are
# kept so mockups can be reviewed later.

SESSION_DIR="$1"

if [[ -z "$SESSION_DIR" ]]; then
  echo '{"error": "Usage: stop-server.sh <session_dir>"}'
  exit 1
fi

STATE_DIR="${SESSION_DIR}/state"
PID_FILE="${STATE_DIR}/server.pid"
SERVER_ID_FILE="${STATE_DIR}/server-instance-id"

mark_stopped() {
  local reason="$1"
  rm -f "${STATE_DIR}/server-info"
  printf '{"reason":"%s","timestamp":%s}\n' "$reason" "$(date +%s)" > "${STATE_DIR}/server-stopped"
}

read_expected_server_id() {
  [[ -f "$SERVER_ID_FILE" ]] || return 1
  local id
  id="$(tr -d '\r\n' < "$SERVER_ID_FILE" 2>/dev/null || true)"
  [[ "$id" =~ ^[A-Za-z0-9_-]{32,64}$ ]] || return 1
  printf '%s\n' "$id"
}

# A pid file holds a positive decimal pid; anything else is not a process.
# bash rejects garbage, an empty string or an out-of-range number with a usage
# error rather than ESRCH, and `kill -0 0` succeeds by signalling the caller's
# own process group. Of kill -0's failures only "No such process" means gone:
# EPERM is a live process this shell may not signal (a sandbox refuses signals
# to processes it did not start), and a failure nobody listed is taken as
# alive too, so the session files are never discarded on a guess.
process_exists() {
  local err pid_re='^[1-9][0-9]{0,9}$'
  [[ "$1" =~ $pid_re ]] || return 1
  (( 10#$1 <= 2147483647 )) || return 1
  err="$(LC_ALL=C; kill -0 "$1" 2>&1)" && return 0
  [[ "$err" != *"No such process"* ]]
}

command_line_for_pid() {
  local pid="$1"
  if [[ -r "/proc/$pid/cmdline" ]]; then
    tr '\0' '\n' < "/proc/$pid/cmdline" 2>/dev/null || true
    return 0
  fi
  ps -ww -p "$pid" -o command= 2>/dev/null || ps -f -p "$pid" 2>/dev/null | sed '1d' || true
}

command_has_server_id() {
  local pid="$1"
  local expected="$2"
  local expected_arg="--brainstorm-server-id=$expected"
  if [[ -r "/proc/$pid/cmdline" ]]; then
    local arg
    while IFS= read -r -d '' arg || [[ -n "$arg" ]]; do
      [[ "$arg" == "$expected_arg" ]] && return 0
    done < "/proc/$pid/cmdline"
    return 1
  fi
  local command_line
  command_line="$(command_line_for_pid "$pid")"
  if [[ -z "$command_line" ]]; then
    # A live process always has a command line, so an empty one means ps could
    # not be run (a sandbox refuses it) -- unless the process has just exited.
    process_exists "$pid" && return 2
    return 1
  fi
  case " $command_line " in
    *" $expected_arg "*) return 0 ;;
    *) return 1 ;;
  esac
}

# Confirm a PID has this session's per-start instance id, not just a familiar
# process name. Ambiguous or legacy metadata fails closed as stale_pid.
# Returns 0 for our server, 1 for anything else, and 2 for a live process
# whose command line cannot be read.
is_brainstorm_server() {
  process_exists "$1" || return 1
  local expected_id
  expected_id="$(read_expected_server_id)" || return 1
  command_has_server_id "$1" "$expected_id"
}

if [[ -f "$PID_FILE" ]]; then
  pid=$(cat "$PID_FILE")

  is_brainstorm_server "$pid"
  identity=$?

  # Leave the session files alone: if this is our server, they are the only
  # handle on it, and stale_pid would discard them while it keeps running.
  if [[ "$identity" -eq 2 ]]; then
    echo '{"status": "unverified", "error": "cannot read the process command line to confirm the server identity"}'
    exit 1
  fi

  # Refuse to signal a PID we can't prove is our server. A stale pid file may
  # point at an unrelated process after a reboot/PID wraparound.
  if [[ "$identity" -ne 0 ]]; then
    rm -f "$PID_FILE" "$SERVER_ID_FILE"
    mark_stopped "stale_pid"
    echo '{"status": "stale_pid"}'
    exit 0
  fi

  # Try to stop gracefully, then force. A kill refused with "not permitted" is
  # a live process this shell may not signal (a sandbox refuses signals to
  # processes it did not start), not a dead one: when every attempt is refused
  # and the process is still there, the stop is unverified and the session
  # files stay, exactly as the identity path reports it.
  unsignalable="true"
  if err="$(LC_ALL=C; kill "$pid" 2>&1)"; then
    unsignalable="false"
  elif [[ "$err" != *"not permitted"* ]]; then
    unsignalable="false"
  fi

  # Wait for graceful shutdown (up to ~2s)
  for _ in {1..20}; do
    process_exists "$pid" || break
    sleep 0.1
  done

  # If still running, escalate to SIGKILL
  if process_exists "$pid"; then
    if err="$(LC_ALL=C; kill -9 "$pid" 2>&1)"; then
      unsignalable="false"
    elif [[ "$err" != *"not permitted"* ]]; then
      unsignalable="false"
    fi
    sleep 0.1
  fi

  if process_exists "$pid"; then
    if [[ "$unsignalable" == "true" ]]; then
      echo '{"status": "unverified", "error": "this shell may not signal the server; session files kept"}'
      exit 1
    fi
    echo '{"status": "failed", "error": "process still running"}'
    exit 1
  fi

  rm -f "$PID_FILE" "$SERVER_ID_FILE" "${STATE_DIR}/server.log"
  mark_stopped "stop-server.sh"

  # Only delete ephemeral /tmp directories
  if [[ "$SESSION_DIR" == /tmp/* ]]; then
    rm -rf "$SESSION_DIR"
  fi

  echo '{"status": "stopped"}'
else
  echo '{"status": "not_running"}'
fi