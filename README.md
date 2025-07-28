# RACADM
Dell 서버 관리를 위한 스크립트

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

```
