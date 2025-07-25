#!/bin/bash

# iDRAC 로그인 사용자 이름 설정
RACUSER="root"

# 로그 저장 디렉토리 및 기타 설정
log_base_dir="./TSRLog" # 기본 로그 저장 디렉토리
client_name=""
max_jobs=10 # 동시에 실행할 최대 작업 수 (기존 4개에서 10개로 증가)
current_jobs=0

# racadm 명령어의 경로 (환경에 맞게 수정 필요)
# 시스템 PATH에 racadm이 없으면 이 변수를 설정하세요.
# 예: RACADM_COMMAND="/opt/dell/srvadmin/bin/idracadm7"
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

							        # 재시도 설정을 위한 변수
								    local MAX_RETRIES=3
								        local RETRY_DELAY=10 # 초

									    # TSR 수집 작업 시작 및 Job ID 추출 (재시도 로직 포함)
									        for i in $(seq 1 $MAX_RETRIES); do
										        # --nocertwarn 옵션 추가
											        racadm_output=$("$RACADM_COMMAND" -r "$idrac_ip" -u "$RACUSER" -p "$RACPSWD" --nocertwarn techsupreport collect -t SysInfo,TTYLog)
												        job_id=$(echo "$racadm_output" | grep -oP 'JID_\d+')

													        if [[ -n $job_id ]]; then
														            echo "Job ID for $idrac_ip: $job_id"
															                break # 성공하면 루프 종료
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

																																	        # TSR 진행 상태 확인
																																		    while true; do
																																		            echo "Checking job status for $idrac_ip..."
																																			            # --nocertwarn 옵션 추가
																																				            job_status=$("$RACADM_COMMAND" -r "$idrac_ip" -u "$RACUSER" -p "$RACPSWD" --nocertwarn jobqueue view | grep -A 8 "$job_id")

																																					            if [[ -z $job_status ]]; then
																																						                echo "Error: Job ID $job_id not found in the queue for $idrac_ip. It might have completed or failed unexpectedly."
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

																																																			    # TSR 파일 내보내기
																																																			        current_log_base_dir="${log_base_dir}" # 함수 내부에서 사용할 로컬 변수
																																																				    if [[ -n $client_name ]]; then
																																																				            current_log_base_dir="${log_base_dir}/${client_name}"
																																																					        fi
																																																						    log_date_dir="${current_log_base_dir}/$(date +'%Y%m%d')"
																																																						        export_path="${log_date_dir}/${idrac_ip}_tsr.zip"
																																																							    mkdir -p "$log_date_dir"

																																																							        # TSR 내보내기 (재시도 로직 포함)
																																																								    for i in $(seq 1 $MAX_RETRIES); do
																																																								            # --nocertwarn 옵션 추가
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
																																																																															    return 1 # 모든 재시도 실패 시
																																																																															    }

																																																																															    # 옵션 파싱
																																																																															    while getopts "h:f:c:" opt; do
																																																																															        case $opt in
																																																																																        h) idrac_ip=$OPTARG ;; # 단일 iDRAC IP 주소
																																																																																	        f) ip_file=$OPTARG ;; # iDRAC IP 리스트 파일
																																																																																		        c) client_name=$OPTARG ;; # 클라이언트 이름
																																																																																			        *) usage ;;
																																																																																				    esac
																																																																																				    done

																																																																																				    # 옵션 유효성 검사
																																																																																				    if [[ -z $idrac_ip && -z $ip_file ]]; then
																																																																																				        echo "Error: Either -h or -f option is required."
																																																																																					    usage
																																																																																					    fi

																																																																																					    if [[ -n $idrac_ip && -n $ip_file ]]; then
																																																																																					        echo "Error: -h and -f options cannot be used together."
																																																																																						    usage
																																																																																						    fi

																																																																																						    # iDRAC 비밀번호 입력 받기
																																																																																						    read -s -p "Enter iDRAC password (default: calvin): " RACPSWD_INPUT
																																																																																						    # 사용자가 아무것도 입력하지 않았다면 기본값 'calvin' 사용
																																																																																						    RACPSWD="${RACPSWD_INPUT:-calvin}"
																																																																																						    echo # 비밀번호 입력 후 새 줄로 이동

																																																																																						    # 단일 IP 처리
																																																																																						    if [[ -n $idrac_ip ]]; then
																																																																																						        if [[ ! $idrac_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
																																																																																							        echo "Error: Invalid IP address format."
																																																																																								        exit 1
																																																																																									    fi
																																																																																									        collect_tsr "$idrac_ip"
																																																																																										    exit 0
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
																																																																																																									            while [[ $current_jobs -ge $max_jobs ]]; do
																																																																																																										                # 자식 프로세스가 종료되기를 기다림
																																																																																																												            # wait -n은 첫 번째로 종료되는 자식 프로세스를 기다림
																																																																																																													                # 이는 'max_jobs' 개수를 최대한 유지하며 병렬 처리 효율을 높임
																																																																																																															            wait -n
																																																																																																																                # 종료된 프로세스만큼 current_jobs 감소 (모든 자식 프로세스가 종료되면 current_jobs=0)
																																																																																																																		            current_jobs=$(jobs -p | wc -l)
																																																																																																																			            done

																																																																																																																				            collect_tsr "$ip" & # 백그라운드에서 실행
																																																																																																																					            ((current_jobs++))
																																																																																																																						        done < "$ip_file"

																																																																																																																							    wait # 남아 있는 모든 백그라운드 작업 완료 대기
																																																																																																																							        echo "All TSR collection and export tasks completed."
																																																																																																																								fi
