#!/usr/bin/env bash
set -euo pipefail

runner_temp="${RUNNER_TEMP:?RUNNER_TEMP must be set}"
github_env="${GITHUB_ENV:?GITHUB_ENV must be set}"
directory="$runner_temp/lavinmq"
socket="$directory/amqp.sock"

mkdir -p "$directory/data"

cat > "$directory/lavinmq.ini" <<EOF
[main]
data_dir = $directory/data
control_unix_path = $directory/control.sock

[amqp]
port = -1
unix_path = $socket

[mgmt]
port = -1
EOF

lavinmq --config="$directory/lavinmq.ini" \
  >"$directory/lavinmq.log" 2>&1 &
pid=$!
echo "$pid" > "$directory/lavinmq.pid"

for attempt in $(seq 1 30); do
  if [[ -S "$socket" ]]; then
    echo "LAVINMQ_AMQP_UNIXSOCKET=$socket" >> "$github_env"
    exit 0
  fi

  if ! kill -0 "$pid" 2>/dev/null; then
    cat "$directory/lavinmq.log"
    echo "LavinMQ exited before creating its AMQP socket" >&2
    exit 1
  fi

  sleep 1
done

cat "$directory/lavinmq.log"
echo "Timed out waiting for the LavinMQ UNIX socket" >&2
exit 1
