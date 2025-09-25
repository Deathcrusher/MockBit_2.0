#!/bin/bash
# Decryptor: Recover from ransomware
# Usage: bash decryptor.sh [target_dir] [key] [iv]
TARGET_DIR="${1:-/tmp/test_victim}"
KEY="${2:-}"  # Provide key from C2 exfil or note
IV="${3:-$(openssl rand -hex 16)}"  # If not provided, gen new (won't work, use real)

if [[ -z "$KEY" ]]; then
    echo "Key required. Extract from README.txt or C2 logs."
    exit 1
fi

ENCRYPTED_EXT=".seized"

decrypt_file() {
    local file="$1"
    local orig="${file%$ENCRYPTED_EXT}"
    if [[ -f "$file" && -f "$orig" ]]; then  # Backup orig if exists
        cp "$orig" "$orig.bak" 2>/dev/null
    fi
    openssl enc -d -aes-256-cbc -a -k "$KEY" -iv "$IV" -in "$file" -out "$orig" >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        rm "$file"
        echo "Recovered: $orig"
        ((recovered++))
    fi
}

export -f decrypt_file
export KEY IV ENCRYPTED_EXT TARGET_DIR
recovered=0
find "$TARGET_DIR" -type f -name "*$ENCRYPTED_EXT" -print0 | xargs -0 bash -c 'decrypt_file "$@"' _ {}
echo "Recovered $recovered files. Check C2 for full key."
