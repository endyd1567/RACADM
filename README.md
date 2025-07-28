# racadm

Dell iDRAC 환경에서 펌웨어 설정, 로그 수집, 시스템 진단 등을 자동화하기 위한 Bash 스크립트 모음입니다.  
`racadm` CLI를 기반으로 하며, 대량 서버 환경의 운영 효율성을 높이는 데 목적이 있습니다.

---

## 🧩 프로젝트 구조

```
racadm/
├── settings/        # iDRAC 환경 설정 (IPMI, Hot Spare, 비밀번호 등)
├── firmware/        # 소프트웨어 인벤토리 및 펌웨어 업데이트
├── log/             # TSR 및 Lifecycle 로그 수집
└── racadm_config    # 공통 설정 파일
```

---

## 🧰 `racadm` CLI란?

**RACADM(Remote Access Controller Admin)**은 iDRAC 기능을 명령줄에서 사용할 수 있도록 제공하는 Dell의 관리 도구입니다.  
이를 통해 대부분의 작업을 자동화하거나 스크립트를 통해 대규모로 실행할 수 있습니다.

- 공식 명칭: Remote Access Controller Admin
- RACADM install
  - [Windows Dell iDRAC 툴, v11.2.0.0](https://www.dell.com/support/home/en-us/drivers/driversdetails?driverid=j2vkv)
  - [Linux Dell iDRAC 툴, v11.2.0.0](https://www.dell.com/support/home/en-us/drivers/driversdetails?driverid=j72j9)
- 설치 후 `racadm` 명령을 CLI에서 직접 사용 가능

### ✅ 기본 사용 구문

```bash
racadm -r <iDRAC_IP> -u <username> -p <password> <subcommand>
```

### 📌 사용 예시

```bash
# 시스템 정보 조회
racadm -r 192.168.0.2 -u root -p xxxx getsysinfo

# 서버 전원 켜기
racadm -r 192.168.0.2 -u root -p xxxx serveraction powerup
```


---

## ⚙️ `racadm_config` 설정 파일

모든 스크립트는 공통적으로 `racadm_config` 파일을 참조합니다.  

### 예시:

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

---

## 🧪 사용 흐름 예시

1. `racadm_config` 파일에 iDRAC 계정, 비밀번호, 공유폴더 설정 작성
2. `settings/`, `firmware/`, `log/` 디렉토리 내 스크립트 실행
3. 각 스크립트는 설정 파일을 불러와 명령어 실행 및 결과 저장 수행

---

## 🛡️ 주의사항

- 스크립트 실행 전 `racadm` CLI가 설치되어 있어야 합니다.
- 병렬 작업 수(`max_jobs`)는 네트워크 및 iDRAC의 처리 능력을 고려해 설정하세요.

---

