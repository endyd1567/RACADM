#!/bin/bash

# 설정 파일 경로
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../racadm_config"

# 기본값 초기화
RACUSER=""
RACPASS=""
ipmi_state=""
IDRAC_IP=""
IP_FILE=""
max_jobs=10
current_jobs=0

# 사용법 출력
usage() {
    echo "Error: -s option with 0 or 1 is required."
    echo "Usage: $0 -s <0|1> [-h <iDRAC_IP> | -f <file_with_iDRAC_IPs>]"
    echo ""
    echo "Options:"
    echo "  -s <0|1>         Set IPMI over LAN state: 0 (Disabled), 1 (Enabled)"
    echo "  -h <iDRAC_IP>    Target single iDRAC IP"
    echo "  -f <file>        File containing iDRAC IPs (one per line)"
    echo ""
    echo "📌 실행 예시:"
    echo "  $0 -s 1 -h 192.168.0.101"
    echo "  $0 -s 0 -f ip_list.txt"
    exit 1
}

# 옵션 파싱
while getopts "s:h:f:" opt; do
    case $opt in
        s)
            [[ "$OPTARG" != "0" && "$OPTARG" != "1" ]] && usage
            ipmi_state="$OPTARG"
            ;;
        h) IDRAC_IP="$OPTARG" ;;
        f) IP_FILE="$OPTARG" ;;
        *) usage ;;
    esac
done

# 필수 옵션 검사
[[ -z "$ipmi_state" ]] && usage
[[ -z "$IDRAC_IP" && -z "$IP_FILE" ]] && usage
[[ -n "$IDRAC_IP" && -n "$IP_FILE" ]] && echo "❌ Error: -h and -f cannot be used together." && usage

# 설정 파일 파싱
if [[ -f "$CONFIG_FILE" ]]; then
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        case "$key" in
            "RACUSER") RACUSER="$value" ;;
            "RACPSWD") RACPASS="$value" ;;
        esac
    done < "$CONFIG_FILE"
else
    echo "❌ 설정 파일을 찾을 수 없습니다: $CONFIG_FILE"
    exit 1
fi

# 필수 설정 확인
[[ -z "$RACUSER" || -z "$RACPASS" ]] && echo "❌ 설정 파일에 RACUSER 또는 RACPSWD 값이 없습니다." && exit 1

# IPMI LAN 설정 함수
set_ipmi_lan() {
    local ip=$1
    echo "▶ $ip: IPMI over LAN 설정 시도 "
    output=$(racadm -r "$ip" -u "$RACUSER" -p "$RACPASS" set iDRAC.IPMILan.Enable "$ipmi_state" --nocertwarn 2>&1)
    if echo "$output" | grep -qi "successfully"; then
        echo "✅ $ip: 설정 성공 ($ipmi_state)"
    else
        echo "❌ $ip: 설정 실패 - $output"
    fi
}

# 단일 IP 실행
if [[ -n "$IDRAC_IP" ]]; then
    set_ipmi_lan "$IDRAC_IP"
    exit 0
fi

# 다중 IP 실행 (병렬 처리)
if [[ -f "$IP_FILE" ]]; then
    while IFS= read -r ip || [[ -n "$ip" ]]; do
        ip=$(echo "$ip" | xargs)
        [[ -z "$ip" || "$ip" =~ ^# ]] && continue
        if [[ ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "⚠️  Skipping invalid IP: $ip"
            continue
        fi

        while [[ $(jobs -p | wc -l) -ge $max_jobs ]]; do
            wait -n
        done

        set_ipmi_lan "$ip" &
    done < "$IP_FILE"

    wait
    echo "✅ All IPMI over LAN 설정 작업 완료."
else
    echo "❌ 파일을 찾을 수 없습니다: $IP_FILE"
    exit 1
fi
