# racadm/settings

Dell iDRAC 환경 설정 자동화를 위한 Bash 스크립트 모음입니다.  
`racadm` CLI를 활용하여 대량 서버 환경을 효율적으로 설정할 수 있도록 구성되었습니다.

---

## 📁 스크립트 구성

| 파일명 | 기능 설명 |
|--------|-----------|
| `set_ipmi_lan.sh` | iDRAC의 **IPMI over LAN** 설정 (활성화/비활성화) |
| `set_power_hotspare.sh` | 시스템의 **Hot Spare** 기능 설정 |
| `change_root_pw.sh` | iDRAC **root 비밀번호** 변경 |

---

## ⚙ 공통 설정 파일 (`racadm_config`)

스크립트 실행에 필요한 계정 정보와 병렬 처리 수는 `racadm_config` 파일에 작성해야 합니다.

예시:
```ini
# iDRAC 로그인 사용자 이름
RACUSER=root
# iDRAC 비밀번호
RACPSWD=calvin
# CIFS 공유 IP 주소
CIFS_IP=192.168.0.28
# 네트워크 공유 경로
SHARE_PATH=cifs_fw_share
# CIFS 공유 사용자 이름
SHARE_USER=idrac_user
# CIFS 공유 비밀번호
SHARE_PASS=Dellemc1234!
# 동시에 실행할 최대 작업 수
max_jobs=10

