#!/bin/bash

# iDRAC 로그인 사용자 이름 설정
RACUSER="root"

# 로그 저장 디렉토리 및 기타 설정
log_base_dir="./TSRLog" # 기본 로그 저장 디렉토리
client_name=""
max_jobs=10 # 동시에 실행할 최대 작업 수
current_jobs=0

# racadm 명령어의 경로
RACADM_COMMAND="racadm"

# Usage 출력 함수
usage() {
    echo "Usage: $0 [-h <iDRAC_IP> | -f <file_with_iDRAC_IPs>] [-c <client_name>]"
    echo "Options:"
    echo "  -h <iDRAC_IP>     Specify a single iDRAC IP address"
    echo "  -f <file>         Specify a file containing iDRAC IP addresses (one per line)"
    echo "  -c <client_name>  Specify a client name for log directory"
    exit 1
}

# TSR 수집 함수
collect_tsr() {
    local idrac_ip=$1
    echo "Collecting TSR from $idrac_ip..."

    local racadm_output
    local job_id
    local job_status
    local percent_complete
    local current_log_base_dir
    local log_date_dir
    local export_path

    local MAX_RETRIES=3
    local RETRY_DELAY=10

    for i in $(seq 1 $MAX_RETRIES); do
        racadm_output=$("$RACADM_COMMAND" -r "$idrac_ip" -u "$RACUSER" -p "$RACPSWD" --nocertwarn techsupreport collect -t SysInfo,TTYLog)
        job_id=$(echo "$racadm_output" | grep -oP 'JID_\d+')
        if [[ -n $job_id ]]; then
            echo "Job ID for $idrac_ip: $job_id"
            break
        else
            echo "Attempt $i failed to initiate TSR collection for $idrac_ip."
            if [[ $i -lt $MAX_RETRIES ]]; then
                echo "Retrying in $RETRY_DELAY seconds..."
                sleep $RETRY_DELAY
            else
                echo "Error: Failed to initiate TSR collection for $idrac_ip after $MAX_RETRIES attempts."
                return 1
            fi
        fi
    done

    while true; do
        echo "Checking job status for $idrac_ip..."
        job_status=$("$RACADM_COMMAND" -r "$idrac_ip" -u "$RACUSER" -p "$RACPSWD" --nocertwarn jobqueue view | grep -A 8 "$job_id")
        if [[ -z $job_status ]]; then
            echo "Error: Job ID $job_id not found."
            return 1
        fi
        percent_complete=$(echo "$job_status" | grep 'Percent Complete' | grep -oP '\d+')
        echo "Percent complete for $idrac_ip: $percent_complete%"
        if [[ $percent_complete -eq 100 ]]; then
            echo "TSR collection completed for $idrac_ip."
            break
        fi
        sleep 60
    done

    current_log_base_dir="$log_base_dir"
    if [[ -n $client_name ]]; then
        current_log_base_dir="${log_base_dir}/${client_name}"
    fi
    log_date_dir="${current_log_base_dir}/$(date +'%Y%m%d')"
    export_path="${log_date_dir}/${idrac_ip}_tsr.zip"
    mkdir -p "$log_date_dir"

    for i in $(seq 1 $MAX_RETRIES); do
        "$RACADM_COMMAND" -r "$idrac_ip" -u "$RACUSER" -p "$RACPSWD" --nocertwarn techsupreport export -f "$export_path"
        if [[ $? -eq 0 ]]; then
            echo "TSR exported successfully to $export_path."
            return 0
        else
            echo "Attempt $i failed to export TSR for $idrac_ip."
            if [[ $i -lt $MAX_RETRIES ]]; then
                echo "Retrying in $RETRY_DELAY seconds..."
                sleep $RETRY_DELAY
            else
                echo "Error: Failed to export TSR for $idrac_ip after $MAX_RETRIES attempts."
                return 1
            fi
        fi
    done
}

while getopts "h:f:c:" opt; do
    case $opt in
        h) idrac_ip=$OPTARG ;;
        f) ip_file=$OPTARG ;;
        c) client_name=$OPTARG ;;
        *) usage ;;
    esac
done

if [[ -z $idrac_ip && -z $ip_file ]]; then
    echo "Error: Either -h or -f option is required."
    usage
fi

if [[ -n $idrac_ip && -n $ip_file ]]; then
    echo "Error: -h and -f options cannot be used together."
    usage
fi

read -s -p "Enter iDRAC password (default: calvin): " RACPSWD_INPUT
RACPSWD="${RACPSWD_INPUT:-calvin}"
echo

if [[ -n $idrac_ip ]]; then
    if [[ ! $idrac_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Invalid IP address format."
        exit 1
    fi
    collect_tsr "$idrac_ip"
    exit 0
fi

if [[ -n $ip_file ]]; then
    if [[ ! -f $ip_file ]]; then
        echo "Error: File '$ip_file' not found."
        exit 1
    fi
    while IFS= read -r ip_line || [[ -n $ip_line ]]; do
        ip=$(echo "$ip_line" | xargs)
        if [[ -z "$ip" || "$ip" =~ ^# ]]; then
            continue
        fi
        if [[ ! $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "Warning: Skipping invalid IP address '$ip'"
            continue
        fi
        while [[ $current_jobs -ge $max_jobs ]]; do
            wait -n
            current_jobs=$(jobs -p | wc -l)
        done
        collect_tsr "$ip" &
        ((current_jobs++))
    done < "$ip_file"
    wait
    echo "All TSR collection and export tasks completed."
fi
