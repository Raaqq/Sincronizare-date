#!/bin/bash
#192.168.56.101 ip masina virtuala
clear
#separat pentru acele 10 minute sincronizate si sa fie bidirectional local -> remote si remote -> local
script=sync.sh
if [[ ! -f $script ]]
then
echo "#!/bin/bash" > $script

cat << 'EOF' >> "$script"

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
EOF

sudo chmod +x $script

fi

schimba_date(){
read -p "Scrieti numele masinii remote: " remote_name

read -p "Scrieti ip-ul numele masinii remote: " remote_ip

until  ssh -o BatchMode=yes -o ConnectTimeout=5 "$remote_name@$remote_ip" exit 0
do

echo "Nume sau ip gresit reintroduceti"

read -p "Nume:" remote_name

read -p "IP:" remote_ip

done

echo
}

sincronizare_fis(){
if [[ -n $remote_name || -n $remote_ip ]]
then
echo "Scrieti locatia fisierului local(calea completa)"
echo "Ex:/home/user/director"
read local

while [ ! -d "$local" ] 
do

read -p "Locatia data este invalida reintroduceti: " local

done

echo

echo "Scrieti locatia fisierului remote(calea completa)"
echo "Ex:/home/user_remote/director"
read remote

while ssh -o BatchMode=yes -o ConnectTimeout=5 "$remote_name@$remote_ip" '[ ! -d '$remote' ]' 
do

read -p "Locatia data este invalida reintroduceti: " remote

done

echo



gnome-terminal -- /home/rares/Desktop/"$script" $local $remote_name $remote_ip $remote 
else
    echo "Nu au fost selectate datele pentru conectarea la alta masina"
fi
}

afiseaza_datele(){
    echo "Nume remote: $remote_name"
    echo "IP remote: $remote_ip"
}

PS3="Alege o optiune: "

select meniu in "Sincronizeaza fisiere" "Schimba datele din ssh" "Afiseaza datele remote" "Exit"
do
    case $REPLY in 
    1)sincronizare_fis ;;
    2)schimba_date ;;
    3)afiseaza_datele ;;
    4)exit 0 ;;
    *)echo "Optiune invalida"
    esac
done
