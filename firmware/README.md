다음은 `racadm/firmware` 디렉토리에 맞춘 `README.md` 파일 내용입니다. `settings` 디렉토리와 동일한 스타일을 유지하면서 작성했습니다:

---

````markdown
# firmware

Dell iDRAC의 펌웨어 정보 수집 및 펌웨어 업데이트 자동화를 위한 Bash 스크립트 모음입니다.

---

## 📁 스크립트 구성

| 파일명 | 기능 설명 |
|--------|-----------|
| `get_swinventory.sh` | iDRAC 장비의 **펌웨어 및 소프트웨어 인벤토리 정보 수집** |
| `update_firmware.sh` | iDRAC 장비에 **네트워크 공유를 통한 펌웨어 업데이트 수행** |

---

## 🛠 사용법 요약

### `get_swinventory.sh`

```bash
./get_swinventory.sh [-h <iDRAC_IP> | -f <ip_list.txt>] [-c <client_name>]
````

* `-h`: 단일 iDRAC IP 지정
* `-f`: IP 리스트 파일 지정 (한 줄당 하나의 IP)
* `-c`: 로그 저장 시 사용할 클라이언트 이름 (디폴트: `default_client`)

---

### `update_firmware.sh`

```bash
./update_firmware.sh -F <firmware_filename> [-h <iDRAC_IP> | -f <ip_list.txt>]
```

* `-F`: CIFS 공유에 업로드된 펌웨어 파일 이름 (예: `BIOS_1.3.4.exe`)
* `-h`: 단일 iDRAC IP 지정
* `-f`: IP 리스트 파일 지정 (한 줄당 하나의 IP)

※ CIFS 설정(`CIFS_IP`, `SHARE_PATH`, `SHARE_USER`, `SHARE_PASS`)은 `../racadm_config`에서 관리됩니다.

---

## 💡 실행 예시

```bash
# 단일 장비에서 인벤토리 수집
./get_swinventory.sh -h 192.168.0.100 -c clientA

# 여러 장비 대상 인벤토리 수집
./get_swinventory.sh -f ip_list.txt -c customer1

# 단일 장비 펌웨어 업데이트
./update_firmware.sh -F BIOS_1.3.4.exe -h 192.168.0.101

# 여러 장비 대상 펌웨어 업데이트
./update_firmware.sh -F BIOS_1.3.4.exe -f ip_list.txt
```

---

```

원하시면 위 내용을 `README.md` 파일로 저장해드릴게요. 저장할까요?
```
