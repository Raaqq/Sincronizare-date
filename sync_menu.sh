#!/bin/bash

clear
cront=off
script=sync-files.sh

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
echo "Scrieti locatia fisierului local(calea absoluta)"
echo "Ex:/home/user/director"
read local

while [ ! -d "$local" ] 
do

read -p "Locatia data este invalida reintroduceti: " local

done

echo

echo "Scrieti locatia fisierului remote(calea absoluta)"
echo "Ex:/home/user_remote/director"
read remote

while ssh -o BatchMode=yes -o ConnectTimeout=5 "$remote_name@$remote_ip" '[ ! -d '$remote' ]' 
do

read -p "Locatia data este invalida reintroduceti: " remote

done

echo

 if [[ $cront == "on" ]]
    then
      nohup bash cronjob.sh > /dev/null &
    fi

gnome-terminal -- bash "$script" $local $remote_name $remote_ip $remote
else
    echo "Nu au fost selectate datele pentru conectarea la alta masina"
fi
}

timer(){
    if [[ $cront == "off" ]]
    then
        cront=on
        bash "$(pwd)/timer.sh" $cront

    elif [[ $cront == "on" ]]
    then
        cront=off
        bash "$(pwd)/timer.sh" $cront
    fi
}

afiseaza_datele(){
    echo "Nume remote: $remote_name"
    echo "IP remote: $remote_ip"
}

PS3="Alege o optiune: "

select meniu in "Sincronizeaza fisiere" "Schimba datele din ssh" "Afiseaza datele remote" "Switch on/off timer" "Exit"
do
    case $REPLY in 
    1)sincronizare_fis ;;
    2)schimba_date ;;
    3)afiseaza_datele ;;
    4)timer ;;
    5)exit 0 ;;
    *)echo "Optiune invalida"
    esac
done