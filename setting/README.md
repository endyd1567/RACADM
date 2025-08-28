# settings

Dell iDRAC 환경 설정 자동화를 위한 Bash 스크립트 모음입니다.  

---

## 📁 스크립트 구성

| 파일명 | 기능 설명 |
|--------|-----------|
| `set_ipmi_lan.sh` | iDRAC의 **IPMI over LAN** 설정 (활성화/비활성화) |
| `set_power_hotspare.sh` | 시스템 power **Hot Spare** 기능 설정 (활성화/비활성화) |
| `change_root_pw.sh` | iDRAC **root 비밀번호** 변경 |
| `change_idrac_ip_by_service_tag.sh` | 서비스태그 기반으로 iDRAC **고정 IP 일괄 설정** |

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

### `change_idrac_ip_by_service_tag.sh`

```bash
./change_idrac_ip_by_service_tag.sh
```

- `idrac_static_config` 설정파일을 기준으로:
  - iDRAC 로그인 정보
  - 공통 네트워크 설정 (서브넷, 게이트웨이)
  - 서비스태그 ↔ Static IP 매핑
  - DHCP로 할당된 iDRAC IP 목록
- DHCP로 연결된 각 iDRAC에 접속해 서비스태그를 조회하고, 미리 정의한 Static IP로 변경합니다.
- **변경 전 매핑 미리보기 및 사용자 확인** 절차 포함

#### 📝 설정파일 예시 (`idrac_static_config`)

```
# iDRAC 로그인 정보
RACUSER=root
RACPSWD=calvin

# 네트워크 설정
SUBNET_MASK=255.255.255.0
GATEWAY=192.168.0.1

# DHCP로 할당된 iDRAC IP 목록
192.168.0.1
192.168.0.2
192.168.0.3
192.168.0.4

# 서비스태그 ↔ Static IP 매핑
1N69WL2=192.168.0.200
2CTZB53=192.168.0.201
2DM9WL7=192.168.0.202
9DZ12ZD=192.168.0.203
```

---


## 💡 실행 예시

```bash
# 단일 iDRAC에서 IPMI over LAN 활성화
./set_ipmi_lan.sh -s 1 -h 192.168.0.101

# IP 목록 파일을 기준으로 Hot Spare 비활성화
./set_power_hotspare.sh -s 0 -f ip_address

# 비밀번호 일괄 변경 (병렬처리)
./change_root_pw.sh -o calvin -n NewP@ssw0rd -f ip_address

# 서비스태그 기반으로 Static IP 일괄 설정
./change_idrac_ip_by_service_tag.sh
```

---



