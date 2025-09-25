#!/bin/bash
# Decryptor: Recover from ransomware
# Usage: bash decryptor.sh [target_dir] [key] [iv]

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

TARGET_DIR_DEFAULT="${TARGET_DIR:-/tmp/test_victim}"
TARGET_DIR="${1:-$TARGET_DIR_DEFAULT}"
KEY="${2:-${KEY:-}}"  # Provide key from C2 exfil or note
IV="${3:-${IV:-$(openssl rand -hex 16)}}"  # If not provided, gen new (won't work, use real)

if [[ -z "$KEY" ]]; then
    echo "Key required. Extract from README.txt or C2 logs."
    exit 1
fi

ENCRYPTED_EXT="${ENCRYPTED_EXT:-.seized}"

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
find "$TARGET_DIR" -type f -name "*$ENCRYPTED_EXT" -print0 | xargs -0 -n 1 bash -c 'decrypt_file "$@"' _
echo "Recovered $recovered files. Check C2 for full key."
