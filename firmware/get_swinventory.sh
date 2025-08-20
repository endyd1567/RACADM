#!/bin/bash

# 스크립트 이름: get_swinventory.sh
# 설명: Dell iDRAC에서 소프트웨어/펌웨어 인벤토리 정보를 수집합니다.

# 기본값
OUTPUT_DIR_BASE="swinventory_logs"
DATE_SUFFIX=$(date +%Y%m%d_%H%M%S)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../racadm_config"

# 초기화
SINGLE_IP=""
IP_FILE=""
CLIENT_NAME=""
RACUSER=""
RACPSWD=""
max_jobs=""

# 함수: 사용법 출력
usage() {
    echo "Error: Either -h or -f option is required."
    echo "Usage: $0 [-h <iDRAC_IP> | -f <file_with_iDRAC_IPs>] [-c <client_name>]"
    echo "Options:"
    echo "  -h <iDRAC_IP>       Specify a single iDRAC IP address"
    echo "  -f <file>           Specify a file containing iDRAC IP addresses (one per line)"
    echo "  -c <client_name>    Specify a client name for log directory"
    exit 1
}

# 옵션 파싱
while getopts "h:f:c:" opt; do
    case ${opt} in
        h) SINGLE_IP=${OPTARG} ;;
        f) IP_FILE=${OPTARG} ;;
        c) CLIENT_NAME=${OPTARG} ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))

# 옵션 검증: 가장 먼저 수행 (설정파일 파싱보다 우선)
if [[ -z "${SINGLE_IP}" && -z "${IP_FILE}" ]]; then
    usage
fi
if [[ -n "${SINGLE_IP}" && -n "${IP_FILE}" ]]; then
    echo "❌ 오류: -h 와 -f 옵션은 동시에 사용할 수 없습니다."
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
    echo "❌ 오류: 설정 파일을 찾을 수 없습니다: $CONFIG_FILE"
    exit 1
fi

# 필수 설정 확인
if [[ -z "$RACUSER" || -z "$RACPSWD" ]]; then
    echo "❌ 오류: 설정 파일에 RACUSER 또는 RACPSWD 값이 없습니다."
    exit 1
fi

# 클라이언트 이름 기본값
if [[ -z "$CLIENT_NAME" ]]; then
    CLIENT_NAME="default_client"
    echo " ℹ️ 클라이언트 이름이 지정되지 않아 '${CLIENT_NAME}' 사용합니다."
fi

# 함수: 소프트웨어 인벤토리 수집
get_sw_inventory() {
    local ip=$1
    local client_name=$2

    echo "✨ ${ip} 에서 소프트웨어 인벤토리 수집 시작..."
    local output_dir="${OUTPUT_DIR_BASE}/${client_name}"
    mkdir -p "${output_dir}" || { echo "❌ ${output_dir} 디렉터리 생성 실패"; return 1; }

    local inventory_filename="SWInventory_${ip}_${DATE_SUFFIX}.txt"
    local full_path="${output_dir}/${inventory_filename}"

	racadm -r "${ip}" -u "${RACUSER}" -p "${RACPSWD}" swinventory --nocertwarn \
	| sed $'s/\r//g' \
	| awk '
		/^ElementName = / {
			name=$0
			sub(/^ElementName = /,"",name)
			next
		}
		/^Current Version = / && length(name)>0 {
			ver=$0
			sub(/^Current Version = /,"",ver)
			print name " = " ver
			name=""
		}
    ' > "${full_path}"


    if [[ $? -eq 0 ]]; then
        echo " ✅ ${ip} 의 인벤토리 정보가 ${full_path} 에 저장되었습니다."
    else
        echo "❌ 오류: ${ip} 에서 인벤토리 수집 실패"
    fi
}

# 출력 디렉토리 생성
mkdir -p "${OUTPUT_DIR_BASE}" || { echo "❌ ${OUTPUT_DIR_BASE} 디렉터리 생성 실패"; exit 1; }

# 단일 IP 처리
if [[ -n "${SINGLE_IP}" ]]; then
    get_sw_inventory "${SINGLE_IP}" "${CLIENT_NAME}"
    exit 0
fi

# IP 파일 처리
if [[ ! -f "${IP_FILE}" ]]; then
    echo "❌ 오류: IP 파일 '${IP_FILE}' 을 찾을 수 없습니다."
    exit 1
fi

current_jobs=0
while IFS= read -r ip_address || [[ -n "$ip_address" ]]; do
    [[ -z "${ip_address}" || "${ip_address}" =~ ^# ]] && continue
    get_sw_inventory "${ip_address}" "${CLIENT_NAME}" &

    ((current_jobs++))
    if [[ -n "$max_jobs" && $current_jobs -ge $max_jobs ]]; then
        wait -n
        ((current_jobs--))
    fi
done < "${IP_FILE}"

wait

echo "---"
echo "✅ 모든 소프트웨어 인벤토리 수집이 완료되었습니다."
