#!/bin/bash

# 설정 파일 위치
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../racadm_config"

# 기본값 초기화
RACUSER=""
RACPSWD=""
max_jobs=""
current_jobs=0
hotspare_state=""
idrac_ip=""
ip_file=""

# 사용법 출력
usage() {
    echo "Usage: $0 -s <0|1> [-h <iDRAC_IP> | -f <file_with_iDRAC_IPs>]"
    echo ""
    echo "Options:"
    echo "  -s <0|1>         Set Hot Spare state: 0 (Disabled), 1 (Enabled)"
    echo "  -h <iDRAC_IP>    Target single iDRAC IP"
    echo "  -f <file>        File containing iDRAC IPs (one per line)"
    echo ""
    echo "📌 실행 예시:"
    echo "  $0 -s 1 -h 192.168.0.101"
    echo "  $0 -s 0 -f idrac_list.txt"
    exit 1
}

# 옵션 파싱 (먼저 수행)
while getopts "s:h:f:" opt; do
    case $opt in
        s) hotspare_state=$OPTARG ;;
        h) idrac_ip=$OPTARG ;;
        f) ip_file=$OPTARG ;;
        *) usage ;;
    esac
done

# 입력값 검증
if [[ -z $hotspare_state || ! $hotspare_state =~ ^[01]$ ]]; then
    echo "❌ Error: -s option with 0 or 1 is required."
    usage
fi
if [[ -z $idrac_ip && -z $ip_file ]]; then
    echo "❌ Error: Either -h or -f option is required."
    usage
fi
if [[ -n $idrac_ip && -n $ip_file ]]; then
    echo "❌ Error: -h and -f cannot be used together."
    usage
fi

# 설정 파일 직접 파싱
if [[ -f "$CONFIG_FILE" ]]; then
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        key=$(echo "$key")
        value=$(echo "$value")
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        case "$key" in
            "RACUSER") RACUSER="$value" ;;
            "RACPSWD") RACPSWD="$value" ;;
            "max_jobs") max_jobs="$value" ;;
        esac
    done < "$CONFIG_FILE"
else
    echo "❌ 설정 파일을 찾을 수 없습니다: $CONFIG_FILE"
    exit 1
fi

# 필수 설정 확인
if [[ -z "$RACUSER" || -z "$RACPSWD" ]]; then
    echo "❌ 설정 파일에 RACUSER 또는 RACPSWD 값이 없습니다."
    exit 1
fi

# 핫스페어 설정 함수
set_hotspare() {
    local ip=$1
    echo "⚙️  Setting Hot Spare to $hotspare_state on $ip..."
    racadm -r "$ip" -u "$RACUSER" -p "$RACPSWD" set System.Power.Hotspare.Enable "$hotspare_state" --nocertwarn
    if [[ $? -eq 0 ]]; then
        echo "✅ Hot Spare state set to $hotspare_state on $ip"
    else
        echo "❌ Error setting Hot Spare on $ip"
    fi
}

# 단일 IP 처리
if [[ -n $idrac_ip ]]; then
    if [[ ! $idrac_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "❌ Error: Invalid IP address format."
        exit 1
    fi
    set_hotspare "$idrac_ip"
    exit 0
fi

# 다중 IP 처리 (병렬 실행)
if [[ -n $ip_file ]]; then
    if [[ ! -f $ip_file ]]; then
        echo "❌ Error: File '$ip_file' not found."
        exit 1
    fi

    while IFS= read -r ip || [[ -n $ip ]]; do
        ip=$(echo "$ip" | xargs)
        [[ -z "$ip" || "$ip" =~ ^# ]] && continue
        if [[ ! $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "⚠️  Skipping invalid IP: $ip"
            continue
        fi

        while [[ $current_jobs -ge $max_jobs ]]; do
            wait -n
            current_jobs=$(jobs -p | wc -l)
        done

        set_hotspare "$ip" &
        ((current_jobs++))
    done < "$ip_file"

    wait
    echo "✅ All Hot Spare operations completed."
fi
