#!/bin/bash

LOCAL_DIR=$1
REMOTE_USER=$2
REMOTE_HOST=$3
REMOTE_DIR=$4
TMP_DIR=".sync_tmp"

declare -A recent_files

sync_file() {
    local file_path="$1"
    local rel_path="${file_path#$LOCAL_DIR/}"
    local remote_path="$REMOTE_DIR/$rel_path"
    local temp_dir="$REMOTE_DIR/$TMP_DIR"
    local temp_path="$temp_dir/$(basename "$rel_path")"

    current_time=$(date +%s)
    last_time=${recent_files["$file_path"]}
    if [[ $((current_time - last_time)) -lt 5 ]]; then
        return
    fi
    recent_files["$file_path"]=$current_time

    
    ssh  "$REMOTE_USER@$REMOTE_HOST" "mkdir -p '$(dirname "$remote_path")' '$temp_dir'"
   
    
    if ssh "$REMOTE_USER@$REMOTE_HOST" "[ ! -f '$remote_path' ]"; then
        echo "[+] Fisier nou: $rel_path"
    else
        local local_hash remote_hash
        local_hash=$(sha256sum "$file_path" | cut -d ' ' -f 1)
        remote_hash=$(ssh "$REMOTE_USER@$REMOTE_HOST" "sha256sum '$remote_path' 2>/dev/null | cut -d ' ' -f 1")
        if [[ "$local_hash" == "$remote_hash" ]]; then
            echo "[=] Fisier identic: $rel_path"
            return
        else
            echo "[~] Fisier modificat: $rel_path"
        fi
    fi


    if  scp "$file_path" "$REMOTE_USER@$REMOTE_HOST:$temp_dir"; then

        ssh "$REMOTE_USER@$REMOTE_HOST" "
            while lsof '$remote_path' &>/dev/null; do sleep 1; done
        "
        ssh "$REMOTE_USER@$REMOTE_HOST" "
            mv '$temp_path' '$remote_path'
            rmdir --ignore-fail-on-non-empty '$temp_dir' 2>/dev/null || true"
            
        echo "[✓] Transfer reusit: $rel_path"
    else
        echo "[!] Eroare la transfer: $rel_path"
    fi
}

cleanup_remote_files() {
     ssh -n "$REMOTE_USER@$REMOTE_HOST" "
        find '$REMOTE_DIR' -type f" | while read remote_file; do
        local rel_path="${remote_file#$REMOTE_DIR/}"
        local local_file="$LOCAL_DIR/$rel_path"
        if [[ ! -f "$local_file" ]]; then
            echo "[-] Sters remote: $rel_path"
            ssh -n "$REMOTE_USER@$REMOTE_HOST" "rm -f '$remote_file'"
        fi
    done
}


echo "[*] Monitorizare $LOCAL_DIR..."

pipe="/tmp/sync_pipe_$$"
mkfifo "$pipe"

cleanup() {
    echo "[✗] Oprire monitorizare..."
    rm -f "$pipe"
    exit 0
}

trap cleanup INT TERM EXIT


while IFS= read -r file < "$pipe"; do
    if [[ -f "$file" ]]; then
        echo "[✓] Fisier modificat sau nou: $file"
        sync_file "$file"
    elif [[ -d "$file" ]]; then
        echo "[+] Director detectat: $file"

        prev_count=0
        while true; do
            current_count=$(find "$file" -type f 2>/dev/null | wc -l)
            [[ "$current_count" -eq "$prev_count" ]] && break
            prev_count=$current_count
            sleep 0.5
        done

        mapfile -t all_files < <(find "$file" -type f 2>/dev/null)
        for subfile in "${all_files[@]}"; do
            echo "[→] Fisier gasit in subdirector: $subfile"
            sync_file "$subfile"
        done
    else
        echo "[!] Cleanup declanșat"
        cleanup_remote_files
    fi
done &



inotifywait -m -r -e create,modify,delete,move,moved_to --format '%w%f' "$LOCAL_DIR" > "$pipe"
