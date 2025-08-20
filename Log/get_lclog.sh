#!/bin/bash

# 설정 파일 위치
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../racadm_config"

# 기본값 초기화
RACUSER=""
RACPSWD=""
log_output="false"
log_base_dir="./LifeCycleLog"
start_time=""
end_time=""
client_name=""
remote_idrac=""
ip_file=""

# Usage 출력 함수
usage() {
    echo "Usage: $0 [-h <iDRAC_IP> | -f <file_with_iDRAC_IPs>] [-s <start_time>] [-e <end_time>] [-c <client_name>]"
    echo "Options:"
    echo "  -h <iDRAC_IP>     단일 iDRAC IP"
    echo "  -f <file>         iDRAC IP 리스트가 있는 파일 (한 줄당 하나)"
    echo "  -s <start_time>   로그 시작 시간 (yyyy-mm-dd HH:MM:SS)"
    echo "  -e <end_time>     로그 종료 시간 (yyyy-mm-dd HH:MM:SS)"
    echo "  -c <client_name>  로그 디렉터리에 사용할 클라이언트 이름"
    echo ""
    echo "⚠️  본 스크립트는 'Critical, Warning' 수준의 Lifecycle 로그만 수집합니다."
	echo "📌 실행 예시:"
    echo "  $0 -h 192.168.0.101"
    echo "  $0 -h 192.168.0.101 -s '2025-07-01 00:00:00' -e '2025-07-28 23:59:59' -c siteA"
    echo "  $0 -f ./ip_list.txt -c customerB"
    echo "  $0 -f ./ip_list.txt -s '2025-07-01 00:00:00' -e '2025-07-28 23:59:59'"
    exit 1
}

# 옵션 처리 (가장 먼저 수행)
while getopts "h:f:s:e:c:" opt; do
    case $opt in
        h) remote_idrac=$OPTARG ;;
        f) ip_file=$OPTARG ;;
        s) start_time=$OPTARG ;;
        e) end_time=$OPTARG ;;
        c) client_name=$OPTARG ;;
        *) usage ;;
    esac
done

# 필수 옵션 검증
if [[ -z $remote_idrac && -z $ip_file ]]; then
    echo "❌ Error: -h 또는 -f 옵션 중 하나는 반드시 지정해야 합니다."
    usage
fi
if [[ -n $remote_idrac && -n $ip_file ]]; then
    echo "❌ Error: -h 와 -f 옵션은 동시에 사용할 수 없습니다."
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
        esac
    done < "$CONFIG_FILE"
else
    echo "❌ 설정 파일을 찾을 수 없습니다: $CONFIG_FILE"
    exit 1
fi

# 필수 설정값 확인
if [[ -z "$RACUSER" || -z "$RACPSWD" ]]; then
    echo "❌ 설정 파일에 RACUSER 또는 RACPSWD 값이 없습니다."
    exit 1
fi

# 로그 저장 여부 묻기
ask_log_saving() {
    read -p "Do you want to save logs? (y/n): " answer
    case $answer in
        [Yy]*) log_output="true" ;;
        [Nn]*) log_output="false" ;;
        *) echo "Invalid input. Defaulting to no log saving."; log_output="false" ;;
    esac
}
ask_log_saving

# 로그 디렉토리 설정
if [[ $log_output == "true" ]]; then
    [[ -n $client_name ]] && log_base_dir="${log_base_dir}/${client_name}"
    log_date_dir="${log_base_dir}/$(date +"%Y%m%d")"
    mkdir -p "$log_date_dir"
    echo "📁 Logs will be saved in directory: $log_date_dir"
fi

# iDRAC 로그 수집 함수
process_idrac_logs() {
    local ip=$1
    echo "📡 Processing iDRAC: $ip"

    # 명령어 구성
    if [[ -z $start_time && -z $end_time ]]; then
        cmd="racadm -r \"$ip\" -u \"$RACUSER\" -p \"$RACPSWD\" lclog view -s Critical,Warning --nocertwarn"
    else
        cmd="racadm -r \"$ip\" -u \"$RACUSER\" -p \"$RACPSWD\" lclog view -s Critical,Warning -r \"$start_time\" -e \"$end_time\" --nocertwarn"
    fi

    # 로그 저장
    if [[ $log_output == "true" ]]; then
        timestamp=$(date +"%H%M%S")
        log_file="${log_date_dir}/${ip}_${timestamp}.log"
        eval "$cmd" > "$log_file" 2>&1
    else
        eval "$cmd"
    fi

    # 오류 확인
    if [[ $? -ne 0 ]]; then
        echo "⚠️ Warning: Unable to connect to $ip. Skipping..."
        return 1
    fi
}

# 단일 IP 처리
if [[ -n $remote_idrac ]]; then
    if [[ ! $remote_idrac =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "❌ Error: Invalid IP address format."
        exit 1
    fi
    process_idrac_logs "$remote_idrac"
fi

# 파일 내 IP 처리
if [[ -n $ip_file ]]; then
    if [[ ! -f $ip_file ]]; then
        echo "❌ Error: File '$ip_file' not found."
        exit 1
    fi

    while IFS= read -r ip || [[ -n $ip ]]; do
        ip=$(echo "$ip")
        [[ -z "$ip" || "$ip" =~ ^# ]] && continue

        if [[ ! $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "⚠️ Warning: Skipping invalid IP address '$ip'"
            continue
        fi

        process_idrac_logs "$ip"
    done < "$ip_file"
fi
