#!/bin/bash

RACUSER="root"
OLDPASS=""
NEWPASS=""
idrac_ip=""
ip_file=""
max_jobs=10
current_jobs=0

usage() {
    echo "Usage: $0 -o <old_password> -n <new_password> [-h <iDRAC_IP> | -f <ip_list_file>]"
    echo "  -o <old_password>    Current password"
    echo "  -n <new_password>    New password to set"
    echo "  -h <iDRAC_IP>        Target single iDRAC IP"
    echo "  -f <ip_file>         File with list of iDRAC IPs (one per line)"
    exit 1
}

change_password() {
    local ip=$1
    echo "[*] Changing password for $ip"
    racadm -r "$ip" -u "$RACUSER" -p "$OLDPASS" set iDRAC.Users.2.Password "$NEWPASS" --nocertwarn
}

while getopts "o:n:h:f:" opt; do
    case $opt in
        o) OLDPASS=$OPTARG ;;
        n) NEWPASS=$OPTARG ;;
        h) idrac_ip=$OPTARG ;;
        f) ip_file=$OPTARG ;;
        *) usage ;;
    esac
done

# 필수 인자 확인
if [[ -z "$OLDPASS" || -z "$NEWPASS" ]] || ([[ -z "$idrac_ip" ]] && [[ -z "$ip_file" ]]); then
    usage
fi

# 단일 IP 처리
if [[ -n "$idrac_ip" ]]; then
    change_password "$idrac_ip"
    exit 0
fi

# 파일 기반 병렬 처리
while IFS= read -r ip || [ -n "$ip" ]; do
    [[ -z "$ip" || "$ip" =~ ^# ]] && continue

    change_password "$ip" &

    current_jobs=$((current_jobs + 1))
    if [ "$current_jobs" -ge "$max_jobs" ]; then
        wait
        current_jobs=0
    fi
done < "$ip_file"

# 남은 백그라운드 작업 대기
wait
