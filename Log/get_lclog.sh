#!/bin/bash

RACUSER="root"
RACPSWD="calvin"
log_output="false" # 로그 저장 여부
log_base_dir="./LifeCycleLog" # 기본 로그 저장 디렉토리
start_time=""
end_time=""
client_name="" # 클라이언트 이름 변수

# Usage 출력 함수
usage() {
    echo "Usage: $0 [-h <iDRAC_IP> | -f <file_with_iDRAC_IPs>] [-r <start_time>] [-e <end_time>] [-c <client_name>]"
        echo "Options:"
	    echo "  -h <iDRAC_IP>   Specify a single iDRAC IP address"
	        echo "  -f <file>       Specify a file containing iDRAC IP addresses (one per line)"
		    echo "  -r <start_time> Start time for logs in format 'yyyy-mm-dd HH:MM:SS'"
		        echo "  -e <end_time>   End time for logs in format 'yyyy-mm-dd HH:MM:SS'"
			    echo "  -c <client_name> Specify a client name for log directory"
			        exit 1
				}

				# 로그 저장 여부 묻기
				ask_log_saving() {
				    read -p "Do you want to save logs? (y/n): " answer
				        case $answer in
					        [Yy]*) log_output="true" ;;
						        [Nn]*) log_output="false" ;;
							        *) echo "Invalid input. Defaulting to no log saving."; log_output="false" ;;
								    esac
								    }

								    # 옵션 처리
								    while getopts "h:f:r:e:c:" opt; do
								        case $opt in
									        h)  # 단일 iDRAC IP
										            remote_idrac=$OPTARG
											                ;;
													        f)  # 파일 입력
														            ip_file=$OPTARG
															                ;;
																	        r)  # 시작 시간
																		            start_time=$OPTARG
																			                ;;
																					        e)  # 종료 시간
																						            end_time=$OPTARG
																							                ;;
																									        c)  # 클라이언트 이름
																										            client_name=$OPTARG
																											                ;;
																													        *)  # 잘못된 옵션
																														            usage
																															                ;;
																																	    esac
																																	    done

																																	    # 옵션 유효성 검증
																																	    if [[ -z $remote_idrac && -z $ip_file ]]; then
																																	        echo "Error: You must provide either -h or -f option."
																																		    usage
																																		    fi

																																		    if [[ -n $remote_idrac && -n $ip_file ]]; then
																																		        echo "Error: Options -h and -f cannot be used together."
																																			    usage
																																			    fi

																																			    # 로그 저장 여부 확인
																																			    ask_log_saving

																																			    # 로그 디렉토리 설정
																																			    if [[ $log_output == "true" ]]; then
																																			        if [[ -n $client_name ]]; then
																																				        log_base_dir="${log_base_dir}/${client_name}"
																																					    fi
																																					        log_date_dir="${log_base_dir}/$(date +"%Y%m%d")"
																																						    mkdir -p "$log_date_dir"
																																						        echo "Logs will be saved in directory: $log_date_dir"
																																							fi

																																							# iDRAC 로그 처리 함수
																																							process_idrac_logs() {
																																							    local ip=$1
																																							        echo "Processing iDRAC: $ip"

																																								    # 명령어 구성
																																								        if [[ -z $start_time && -z $end_time ]]; then
																																									        cmd="racadm -r \"$ip\" -u \"$RACUSER\" -p \"$RACPSWD\" lclog view -s Critical,Warning"
																																										    else
																																										            cmd="racadm -r \"$ip\" -u \"$RACUSER\" -p \"$RACPSWD\" lclog view -s Critical,Warning -r \"$start_time\" -e \"$end_time\""
																																											        fi

																																												    # 로그 저장 경로 생성
																																												        if [[ $log_output == "true" ]]; then
																																													        timestamp=$(date +"%H%M%S")
																																														        log_file="${log_date_dir}/${ip}_${timestamp}.log"
																																															        eval "$cmd" > "$log_file" 2>&1
																																																    else
																																																            eval "$cmd"
																																																	        fi

																																																		    # 종료 코드 확인
																																																		        if [[ $? -ne 0 ]]; then
																																																			        echo "Warning: Unable to connect to $ip. Skipping..."
																																																				        return 1
																																																					    fi
																																																					    }

																																																					    # 단일 IP 처리
																																																					    if [[ -n $remote_idrac ]]; then
																																																					        # IP 형식 확인
																																																						    if [[ ! $remote_idrac =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
																																																						            echo "Error: Invalid IP address format."
																																																							            exit 1
																																																								        fi
																																																									    process_idrac_logs "$remote_idrac"
																																																									    fi

																																																									    # 파일 내 IP 처리
																																																									    if [[ -n $ip_file ]]; then
																																																									        if [[ ! -f $ip_file ]]; then
																																																										        echo "Error: File '$ip_file' not found."
																																																											        exit 1
																																																												    fi

																																																												        while IFS= read -r ip || [[ -n $ip ]]; do
																																																													        # IP 형식 확인
																																																														        if [[ ! $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
																																																															            echo "Warning: Skipping invalid IP address '$ip'"
																																																																                continue
																																																																		        fi
																																																																			        process_idrac_logs "$ip"
																																																																				    done < "$ip_file"
																																																																				    fi

