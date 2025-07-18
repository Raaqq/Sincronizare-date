#!/bin/bash
path=$(pwd)/${BASH_SOURCE[0]}
CRON_JOB="*/10 * * * * $path"
ENABLED="$1"  # on / off

if [[ "$ENABLED" == "on" ]]; then
    crontab -l 2>/dev/null | grep -Fxq "$CRON_JOB" || \
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "[+] Cronjob ACTIVAT."
elif [[ "$ENABLED" == "off" ]]; then
    crontab -l 2>/dev/null | grep -vF "$CRON_JOB" | crontab -
    echo "[-] Cronjob DEZACTIVAT."
else
    echo "[!] Folosește: $0 on | off"
fi