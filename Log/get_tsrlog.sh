#!/bin/bash
# get_tsrlog.sh — racadm_config 참조 + 안전 파서 + 프롬프트 제거

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../racadm_config"

log_base_dir="./TSRLog"
client_name=""
max_jobs=""
RACADM_COMMAND="racadm"
RACUSER=""
RACPSWD=""

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  s="${s//$'\r'/}"
  printf '%s' "$s"
}

usage() {
  echo "Usage: $0 [-h <iDRAC_IP> | -f <file_with_iDRAC_IPs>] [-c <client_name>]"
  echo "Options:"
  echo "  -h <iDRAC_IP>     Single iDRAC IP"
  echo "  -f <file>         File of iDRAC IPs (one per line)"
  echo "  -c <client_name>  Client name for log directory"
  exit 1
}

idrac_ip=""
ip_file=""
while getopts "h:f:c:" opt; do
  case $opt in
    h) idrac_ip="$OPTARG" ;;
    f) ip_file="$OPTARG" ;;
    c) client_name="$OPTARG" ;;
    *) usage ;;
  esac
done

[[ -z $idrac_ip && -z $ip_file ]] && { echo "Error: -h or -f required."; usage; }
[[ -n $idrac_ip && -n $ip_file ]] && { echo "Error: -h and -f cannot be used together."; usage; }

# -------- load config --------
if [[ -f "$CONFIG_FILE" ]]; then
  while IFS= read -r raw || [[ -n "$raw" ]]; do
    line="$(trim "$raw")"
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
    [[ "$line" != *"="* ]] && continue
    key="$(trim "${line%%=*}")"
    val="$(trim "${line#*=}")"
    case "$key" in
      RACUSER)         RACUSER="$val" ;;
      RACPSWD)         RACPSWD="$val" ;;
      max_jobs)        max_jobs="$val" ;;
      RACADM_COMMAND)  RACADM_COMMAND="$val" ;;
      *) ;;
    esac
  done < "$CONFIG_FILE"
else
  echo "❌ 설정 파일을 찾을 수 없습니다: $CONFIG_FILE"; exit 1
fi

[[ -z "$RACUSER" || -z "$RACPSWD" ]] && { echo "❌ 설정 파일에 RACUSER 또는 RACPSWD 값이 없습니다."; exit 1; }
[[ -z "$max_jobs" ]] && max_jobs=10

echo "== Effective Settings =="
echo "  CONFIG_FILE     : $CONFIG_FILE (loaded)"
echo "  RACADM_COMMAND  : $RACADM_COMMAND"
echo "  RACUSER         : $RACUSER"
echo "  max_jobs        : $max_jobs"
echo "  client_name     : ${client_name:-default}"

wait_for_slot() {
  while true; do
    local running
    running=$(jobs -rp | wc -l)
    (( running < max_jobs )) && break
    sleep 0.5
  done
}

collect_tsr() {
  local ip="$1"
  echo "Collecting TSR from $ip..."

  local MAX_RETRIES=3 RETRY_DELAY=10
  local out job_id status percent

  # 1) TSR 수집 요청
  for i in $(seq 1 $MAX_RETRIES); do
    out=$("$RACADM_COMMAND" -r "$ip" -u "$RACUSER" -p "$RACPSWD" --nocertwarn techsupreport collect -t SysInfo,TTYLog 2>&1)
    # 다양한 출력에서 JID 파싱 (PCRE 없이)
    job_id=$(printf '%s' "$out" | grep -o 'JID_[0-9]\+' | head -n1)
    if [[ -n "$job_id" ]]; then
      echo "Job ID for $ip: $job_id"
      break
    fi
    echo "Attempt $i failed to initiate TSR for $ip"
    echo "  output: $out"
    (( i < MAX_RETRIES )) && { echo "Retry in $RETRY_DELAY sec..."; sleep $RETRY_DELAY; } || return 1
  done

  # 2) 진행률 폴링 — 특정 JID만 조회
  while true; do
    echo "Checking job status for $ip..."
    status=$("$RACADM_COMMAND" -r "$ip" -u "$RACUSER" -p "$RACPSWD" --nocertwarn jobqueue view -i "$job_id" 2>&1)
    [[ -z "$status" ]] && { echo "Empty jobqueue output"; return 1; }

    # 2-1) 상태 우선 판정
    if printf '%s' "$status" | grep -q 'Status=Completed'; then
      echo "Percent complete for $ip: 100% (Status=Completed)"
      echo "TSR collection completed for $ip."
      break
    fi
    if printf '%s' "$status" | grep -q 'Status=Failed'; then
      echo "❌ Job failed for $ip"
      echo "$status"
      return 1
    fi

    # 2-2) Percent Complete 파싱: 괄호/문자 제거 후 숫자만 추출
    percent=$(printf '%s' "$status" \
      | awk -F'Percent Complete=' 'NF>1{val=$2; gsub(/[^0-9]/,"",val); if(val!=""){print val; exit}}')

    if [[ "$percent" =~ ^[0-9]+$ ]]; then
      echo "Percent complete for $ip: ${percent}%"
      (( percent >= 100 )) && { echo "TSR collection completed for $ip."; break; }
    else
      echo "Percent not found yet."
    fi

    sleep 60
  done


  # 3) export
  local base="$log_base_dir"
  [[ -n $client_name ]] && base="$base/$client_name"
  local date_dir="$base/$(date +'%Y%m%d')"
  local dst="$date_dir/${ip}_tsr.zip"
  mkdir -p "$date_dir"

  for i in $(seq 1 $MAX_RETRIES); do
    "$RACADM_COMMAND" -r "$ip" -u "$RACUSER" -p "$RACPSWD" --nocertwarn techsupreport export -f "$dst"
    rc=$?
    if [[ $rc -eq 0 ]]; then
      echo "✅ TSR exported: $dst"; return 0
    fi
    echo "Export attempt $i failed for $ip (rc=$rc)"
    (( i < MAX_RETRIES )) && { echo "Retry in $RETRY_DELAY sec..."; sleep $RETRY_DELAY; } || { echo "❌ Export failed for $ip"; return 1; }
  done
}

# ---- run ----
if [[ -n "$idrac_ip" ]]; then
  [[ ! $idrac_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && { echo "Error: Invalid IP address format."; exit 1; }
  collect_tsr "$idrac_ip"; exit $?
fi

if [[ -n "$ip_file" ]]; then
  [[ ! -f "$ip_file" ]] && { echo "Error: File '$ip_file' not found."; exit 1; }
  while IFS= read -r raw || [[ -n "$raw" ]]; do
    ip="$(trim "$raw")"
    [[ -z "$ip" || "${ip:0:1}" == "#" ]] && continue
    [[ ! $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && { echo "Warning: skip invalid IP '$ip'"; continue; }
    wait_for_slot
    collect_tsr "$ip" &
  done < "$ip_file"
  wait
  echo "✅ All TSR collection and export tasks completed."
fi
