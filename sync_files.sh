#!/bin/bash

LOCAL_DIR="/home/rares/Desktop/test"
REMOTE_USER="rares"
REMOTE_HOST="192.168.56.101"
REMOTE_DIR="/home/rares/Desktop/Test"
TMP_DIR=".sync_tmp"
#de modificat sa pot mai multe fisiere o data sa le monitorizez
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


    if  scp "$file_path" "$REMOTE_USER@$REMOTE_HOST:$temp_dir"; then #termina verificare cu hash-uri
        #local_hash=$(sha256sum "$file_path" | cut -d ' ' -f 1)
        #remote_hash=$(ssh "$REMOTE_USER@$REMOTE_HOST" "sha256sum '$remote_path' 2>/dev/null | cut -d ' ' -f 1")
        #if [[ "$local_hash" == "$remote_hash" ]]; then
        #    abc
       # fi
         ssh "$REMOTE_USER@$REMOTE_HOST" "
            while lsof '$remote_path' &>/dev/null; do sleep 1; done
            mv '$temp_path' '$remote_path'
            rmdir --ignore-fail-on-non-empty '$temp_dir' 2>/dev/null || true
        "
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
inotifywait -m -r -e close_write,create,modify,move,delete --format '%w%f' "$LOCAL_DIR" | while read file; do

    if [[ -f "$file" ]]; then
        sync_file "$file"
    else
        cleanup_remote_files
    fi
done 


while true; do
    sleep 600
    echo "[*] Sincronizare completa..."
    find "$LOCAL_DIR" -type f | while read file; do
        sync_file "$file"
    done
    cleanup_remote_files
done
