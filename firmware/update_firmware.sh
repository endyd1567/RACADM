#!/bin/bash

# 설정 파일 위치 (스크립트 기준 상위 디렉터리)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../racadm_config"

# 기본 변수 초기화
RACUSER=""
RACPSWD=""
max_jobs=""
FIRMWARE_FILE=""
CIFS_IP=""
SHARE_PATH=""
SHARE_USER=""
SHARE_PASS=""

NETWORK_LOCATION=""
idrac_ip=""
ip_file=""

RACADM_COMMAND="racadm"

# 사용법 출력 함수
usage() {
    echo "Usage: $0 -F <firmware_filename> [-h <iDRAC_IP> | -f <file_with_iDRAC_IPs>]"
    echo ""
    echo "옵션:"
    echo "  -F <filename>         네트워크 공유 경로에 있는 펌웨어 파일명 (예: BIOS_1.3.4.exe)"
    echo "  -h <iDRAC_IP>         단일 iDRAC IP 주소"
    echo "  -f <ip_file>          여러 iDRAC IP가 적힌 파일 (한 줄당 하나의 IP)"
    echo "예시:"
    echo "  $0 -F BIOS_1.3.4.exe -h 192.168.0.100"
    echo "  $0 -F BIOS_1.3.4.exe -f idrac_ip_list"
    exit 1
}

# 설정 파일 로드 함수
load_config() {
    local config_path="$1"
    if [[ ! -f "$config_path" ]]; then
        echo "Error: 설정 파일 '$config_path' 없음"
        exit 1
    fi

    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        key=$(echo "$key")
        value=$(echo "$value")
        if [[ -z "$key" || "$key" =~ ^# ]]; then
            continue
        fi

        case "$key" in
            "RACUSER") RACUSER="$value" ;;
            "RACPSWD") RACPSWD="$value" ;;
            "CIFS_IP") CIFS_IP="$value" ;;
            "SHARE_PATH") SHARE_PATH="$value" ;;
            "SHARE_USER") SHARE_USER="$value" ;;
            "SHARE_PASS") SHARE_PASS="$value" ;;
            "max_jobs") max_jobs="$value" ;;
            "FIRMWARE_FILE") [[ -z "$FIRMWARE_FILE" ]] && FIRMWARE_FILE="$value" ;;
            *) echo "Warning: Unknown key '$key'" ;;
        esac
    done < "$config_path"
}

# 펌웨어 업데이트 및 상태 확인 함수
update_firmware() {
    local idrac_ip=$1
    echo "Starting firmware update for $idrac_ip from $NETWORK_LOCATION with firmware $FIRMWARE_FILE..."

    local racadm_output
    local job_initiated_successfully=false

    # 재시도 설정을 위한 변수
    local MAX_RETRIES=3
    local RETRY_DELAY=10 # 초

    # 펌웨어 업데이트 작업 시작 (재시도 로직 포함)
    for i in $(seq 1 $MAX_RETRIES); do
        local update_cmd=("$RACADM_COMMAND" -r "$idrac_ip" -u "$RACUSER" -p "$RACPSWD" update -f "$FIRMWARE_FILE" -l "$NETWORK_LOCATION" -u "$SHARE_USER" -p "$SHARE_PASS" --reboot --nocertwarn)
        racadm_output=$("${update_cmd[@]}")

        # 성공 메시지 (initiated, JID 등) 확인
        if echo "$racadm_output" | grep -qiE "initiated|completed|scheduled|JID_"; then
            job_initiated_successfully=true
            local new_job_id=$(echo "$racadm_output" | grep -o 'JID_[0-9]*')
            if [[ -n "$new_job_id" ]]; then
                echo "Firmware update job created for $idrac_ip. Job ID: $new_job_id"
            else
                local clean_output=$(echo "$racadm_output" | tr -d '\n\r' | xargs)
                echo "Firmware update job initiated for $idrac_ip (Message: $clean_output)."
                echo "Will now monitor job queue for the latest firmware update job."
            fi
            break # 성공, 루프 탈출
        else
            echo "Attempt $i failed to initiate repository update for $idrac_ip."
            echo "Output: $racadm_output"
            if [[ $i -lt $MAX_RETRIES ]]; then
                echo "Retrying in $RETRY_DELAY seconds..."
                sleep $RETRY_DELAY
            fi
        fi
    done

    if ! $job_initiated_successfully; then
        echo "Error: Failed to initiate repository update for $idrac_ip after $MAX_RETRIES attempts."
        return 1
    fi

    echo "Waiting a moment for the job to appear in the queue..."
    sleep 30

    # 펌웨어 업데이트 진행 상태 확인 (awk 사용)
    local empty_queue_checks=0
    local MAX_EMPTY_CHECKS=5 # 5분 동안 큐가 비어있는지 확인

    while true; do
        echo "Checking job queue for $idrac_ip..."
        local job_info
        job_info=$("$RACADM_COMMAND" -r "$idrac_ip" -u "$RACUSER" -p "$RACPSWD" --nocertwarn jobqueue view | awk '
            BEGIN {
                FS="=";
                latest_job_id = "";
                latest_job_name = "";
                latest_status = "";
                latest_percent_complete = "";
                current_job_id = "";
                current_status = "";
                is_firmware_update_block = 0;
            }
            /\[Job ID=/ {
                current_job_id = $0;
                is_firmware_update_block = 0;
            }
            /Job Name=/ {
                if ($2 ~ /Firmware Update/) {
                    current_job_name = $0;
                    is_firmware_update_block = 1;
                } else {
                    is_firmware_update_block = 0;
                }
            }
            /Status=/ {
                current_status = $0;
            }
            /Percent Complete=/ {
                current_percent_complete = $0;
                if (is_firmware_update_block) {
                    latest_job_id = current_job_id;
                    latest_job_name = current_job_name;
                    latest_status = current_status;
                    latest_percent_complete = current_percent_complete;
                }
            }
            END {
                if (latest_job_id != "") {
                    gsub(/\[Job ID=|\]/, "", latest_job_id);
                    print latest_job_id;
                    print latest_job_name;
                    print latest_status;
                    print latest_percent_complete;
                }
            }
        ')

        if [[ -z "$job_info" ]]; then
            ((empty_queue_checks++))
            echo "Warning: No 'Firmware Update' job found in the queue for $idrac_ip. (Attempt ${empty_queue_checks}/${MAX_EMPTY_CHECKS})"
            if [[ $empty_queue_checks -ge $MAX_EMPTY_CHECKS ]]; then
                 echo "No active firmware update job found after several checks. Assuming the update process is complete."
                 break
            fi
            sleep 60
            continue
        fi

        empty_queue_checks=0

        # awk 결과 파싱 (캐리지 리턴 문자 제거 및 sed 사용)
        local clean_job_info
        clean_job_info=$(echo -n "$job_info" | tr -d '\r')

        local job_id=$(echo "$clean_job_info" | sed -n '1p' | xargs)
        local job_name=$(echo "$clean_job_info" | sed -n '2p' | cut -d'=' -f2- | xargs)
        local status=$(echo "$clean_job_info" | sed -n '3p' | cut -d'=' -f2- | xargs)
        local percent_complete=$(echo "$clean_job_info" | sed -n '4p' | grep -o '[0-9]*' | xargs)

        echo "Latest Firmware Update Job: ID=$job_id, Name='$job_name', Status=$status, Progress=${percent_complete:-0}%"

        if [[ "$status" == "Failed" ]]; then
            local job_details=$("$RACADM_COMMAND" -r "$idrac_ip" -u "$RACUSER" -p "$RACPSWD" --nocertwarn jobqueue view -i "$job_id")
            local error_message=$(echo "$job_details" | grep 'Message=' | cut -d'=' -f2)
            echo "Error: Firmware update failed for $idrac_ip. Job: $job_name"
            echo "Message: $error_message"
            return 1
        fi

        if [[ "$status" == "Completed" || "$percent_complete" == "100" ]]; then
            echo "Firmware update completed for $idrac_ip. Job: $job_name"
            break
        fi

        sleep 60
    done
    return 0
}


# 옵션 파싱
while getopts "F:h:f:C:" opt; do
    case $opt in
        F) FIRMWARE_FILE=$OPTARG ;;
        h) idrac_ip=$OPTARG ;;
        f) ip_file=$OPTARG ;;
        C) CONFIG_FILE=$OPTARG ;;
        *) usage ;;
    esac
done

# ✅ 사용법 출력 가장 먼저 수행
if [[ -z "$FIRMWARE_FILE" || ( -z "$idrac_ip" && -z "$ip_file" ) || ( -n "$idrac_ip" && -n "$ip_file" ) ]]; then
    usage
fi

# ⚙️ 설정 파일 파싱은 그 이후로 이동
load_config "$CONFIG_FILE"

# 옵션 유효성 검사 (config 파일에서 로드되거나 명령줄에서 지정되었는지 확인)
if [[ -z "$FIRMWARE_FILE" ]]; then
    echo "Error: Firmware filename (-F) is required. Please specify it via command line or in the config file."
    usage
fi
if [[ -z "$CIFS_IP" ]]; then
    echo "Error: CIFS IP address is required. Please specify it in the config file."
    usage
fi
if [[ -z "$RACUSER" ]]; then
    echo "Error: iDRAC username (RACUSER) is required. Please specify it in the config file."
    usage
fi
if [[ -z "$RACPSWD" ]]; then
    echo "Error: iDRAC password (RACPSWD) is required. Please specify it in the config file."
    usage
fi
if [[ -z "$SHARE_PATH" ]]; then
    echo "Error: CIFS share path (SHARE_PATH) is required. Please specify it in the config file."
    usage
fi
if [[ -z "$SHARE_USER" ]]; then
    echo "Error: CIFS share username (SHARE_USER) is required. Please specify it in the config file."
    usage
fi
if [[ -z "$SHARE_PASS" ]]; then
    echo "Error: CIFS share password (SHARE_PASS) is required. Please specify it in the config file."
    usage
fi
if [[ -z "$max_jobs" ]]; then
    echo "Error: Maximum concurrent jobs (max_jobs) is required. Please specify it in the config file."
    usage
fi


if [[ ! $CIFS_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Invalid CIFS IP address format."
    exit 1
fi

if [[ -z $idrac_ip && -z $ip_file ]]; then
    echo "Error: Either -h or -f option is required."
    usage
fi

if [[ -n $idrac_ip && -n $ip_file ]]; then
    echo "Error: -h and -f options cannot be used together."
    usage
fi

# 네트워크 공유 경로 설정 (CIFS_IP가 설정된 후에)
NETWORK_LOCATION="//${CIFS_IP}/${SHARE_PATH}"


# 펌웨어 업데이트 전 설정 출력
echo "----------------------------------------------------"
echo "펌웨어 업데이트 설정 요약:"
echo "  iDRAC 사용자 이름: $RACUSER"
echo "  iDRAC 비밀번호: $RACPSWD"
echo "  네트워크 공유 경로: $NETWORK_LOCATION"
echo "  펌웨어 파일: $FIRMWARE_FILE"

# 단일 IP 또는 다중 IP 표시
if [[ -n "$idrac_ip" ]]; then
    echo "  업데이트 서버: $idrac_ip"
elif [[ -n "$ip_file" ]]; then
    echo "  업데이트 서버:"
    grep -vE '^\s*#|^\s*$' "$ip_file" | while read -r ip; do
        echo "    - $ip"
    done
fi

echo "  최대 동시 작업 수: $max_jobs"
echo "----------------------------------------------------"
echo ""

# 사용자 확인
read -r -p "출력된 설정으로 펌웨어 업데이트를 진행하시겠습니까? (y/n): " confirm_proceed
case "$confirm_proceed" in
    [Yy])
        echo "펌웨어 업데이트를 진행합니다."
        ;;
    *)
        echo "펌웨어 업데이트를 취소합니다."
        exit 0
        ;;
esac


# 단일 IP 처리
if [[ -n $idrac_ip ]]; then
    if [[ ! $idrac_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Invalid IP address format."
        exit 1
    fi
    update_firmware "$idrac_ip"
    exit $?
fi

# 파일 내 IP 처리 (병렬 실행)
if [[ -n $ip_file ]]; then
    if [[ ! -f $ip_file ]]; then
        echo "Error: File '$ip_file' not found."
        exit 1
    fi

    while IFS= read -r ip_line || [[ -n $ip_line ]]; do
        # 주석 라인 또는 빈 라인 건너뛰기, 앞뒤 공백 제거
        ip=$(echo "$ip_line" | xargs)
        if [[ -z "$ip" || "$ip" =~ ^# ]]; then
            continue
        fi

        if [[ ! $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "Warning: Skipping invalid IP address '$ip'"
            continue
        fi

        # 백그라운드 작업 시작 전에 동시에 실행 중인 작업 수를 확인
        while [[ $(jobs -p | wc -l) -ge $max_jobs ]]; do
            # 자식 프로세스가 종료되기를 기다림
            wait -n
        done

        update_firmware "$ip" & # 백그라운드에서 실행
    done < "$ip_file"

    wait # 남아 있는 모든 백그라운드 작업 완료 대기
    echo "All firmware update tasks completed."
fi
