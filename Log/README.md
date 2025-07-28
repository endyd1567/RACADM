# log

Dell iDRAC의 시스템 진단 로그 및 Lifecycle 이벤트 로그 수집을 위한 Bash 스크립트 모음입니다.

---

## 📁 스크립트 구성

| 파일명           | 기능 설명 |
|------------------|-----------|
| `get_lclog.sh`   | iDRAC의 **Lifecycle Log (Critical/Warning 수준)** 수집 |
| `get_tsrlog.sh`  | iDRAC의 **TSR (Technical Support Report)** 수집 및 내보내기 |

---

## 🛠 사용법 요약

### `get_lclog.sh`

```bash
./get_lclog.sh [-h <iDRAC_IP> | -f <ip_list.txt>] [-s <start_time>] [-e <end_time>] [-c <client_name>]
```

- `-h`: 단일 iDRAC IP 지정
- `-f`: IP 리스트 파일 지정 (한 줄당 하나의 IP)
- `-s`: 로그 시작 시간 (`YYYY-MM-DD HH:MM:SS`)
- `-e`: 로그 종료 시간 (`YYYY-MM-DD HH:MM:SS`)
- `-c`: 클라이언트 이름 (로그 저장 디렉토리 하위에 사용됨)

> 🔎 해당 스크립트는 `Critical`, `Warning` 수준 로그만 조회합니다.

---

### `get_tsrlog.sh`

```bash
./get_tsrlog.sh [-h <iDRAC_IP> | -f <ip_list.txt>] [-c <client_name>]
```

- `-h`: 단일 iDRAC IP 지정
- `-f`: IP 리스트 파일 지정 (한 줄당 하나의 IP)
- `-c`: 클라이언트 이름 (TSR 로그 저장 디렉토리 하위에 사용됨)

---

## 💡 실행 예시

```bash
# 단일 iDRAC에서 Lifecycle 로그 수집
./get_lclog.sh -h 192.168.0.101

# 기간 지정하여 Lifecycle 로그 수집
./get_lclog.sh -h 192.168.0.101 -s "2025-07-01 00:00:00" -e "2025-07-28 23:59:59" -c siteA

# 여러 장비 대상 TSR 수집
./get_tsrlog.sh -f ip_list.txt -c customerX
```

---

## 📁 로그 저장 경로

- `get_lclog.sh`: `./LifeCycleLog/<client_name>/<날짜>/IP_시간.log`
- `get_tsrlog.sh`: `./TSRLog/<client_name>/<날짜>/IP_tsr.zip`

> 로그 저장 여부는 실행 중 `y/n` 프롬프트로 지정합니다.

---
