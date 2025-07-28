# settings

Dell iDRAC 환경 설정 자동화를 위한 Bash 스크립트 모음입니다.  

---

## 📁 스크립트 구성

| 파일명 | 기능 설명 |
|--------|-----------|
| `set_ipmi_lan.sh` | iDRAC의 **IPMI over LAN** 설정 (활성화/비활성화) |
| `set_power_hotspare.sh` | 시스템 power **Hot Spare** 기능 설정 (활성화/비활성화) |
| `change_root_pw.sh` | iDRAC **root 비밀번호** 변경 |

---

## 🛠 사용법 요약

### `set_ipmi_lan.sh`

```bash
./set_ipmi_lan.sh -s <0|1> [-h <iDRAC_IP> | -f <ip_list.txt>]
```

- `-s`: IPMI over LAN 상태 (1: 활성화, 0: 비활성화)
- `-h`: 단일 iDRAC IP 지정
- `-f`: IP 리스트 파일 지정 (한 줄당 하나의 IP)

---

### `set_power_hotspare.sh`

```bash
./set_power_hotspare.sh -s <0|1> [-h <iDRAC_IP> | -f <ip_list.txt>]
```

- `-s`: Hot Spare 설정값 (1: 활성화, 0: 비활성화)
- `-h`, `-f`: 위와 동일

---

### `change_root_pw.sh`

```bash
./change_root_pw.sh -o <old_password> -n <new_password> [-h <iDRAC_IP> | -f <ip_list.txt>]
```

- `-o`: 기존 비밀번호
- `-n`: 변경할 비밀번호
- `-h`, `-f`: 위와 동일

---

## 💡 실행 예시

```bash
# 단일 iDRAC에서 IPMI over LAN 활성화
./set_ipmi_lan.sh -s 1 -h 192.168.0.101

# IP 목록 파일을 기준으로 Hot Spare 비활성화
./set_power_hotspare.sh -s 0 -f ip_address

# 비밀번호 일괄 변경 (병렬처리)
./change_root_pw.sh -o calvin -n NewP@ssw0rd -f ip_address
```

---



