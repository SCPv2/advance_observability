# Logging


https://docs.e.samsungsdscloud.com/userguide/compute/virtual_server/how_to_guides/ntp/

```bash
sudo dnf install chrony -y

vi /etc/chrony.conf
```

```conf
# servers
server 198.19.0.54 iburst
```
```bash
sudo systemctl enable chronyd

sudo systemctl restart chronyd

chronyc tracking | grep -E "Reference ID|Leap status"
date '+%Y-%m-%d %H:%M:%S %Z (%z)'
```

Object Storage 버킷 생성

버킷명 : celog

ServiceWatch 로그 그룹 생성 : ServiceWatch > 로그 > 로그 그룹 > 로그 그룹 생성

|로그 그룹명|로그 보관 정책|
|----|----|
|/lab/swmetric/web|30일|
|/lab/swmetric/api|30일|	

로그 스트림 생성 : 로그 그룹 /lab/swmetric/web > 로그 스트림 탭 > 로그 스트림 생성

|로그 스트림명|원본 파일|
|web|	/var/log/logapp/web.log|
|webaccess|	/var/log/logapp/web_access.log|

```bash
sudo tail -f /var/log/logapp/web.log
```
```json
{
   "fileLog": {
      "include": ["/var/log/logapp/web.log"],
      "operators": {
         "regex": "^(?P<timestamp>\\S+ \\S+)\\s+(?P<message>.*)$",
         "timestamp": { "layout_type": "gotime", "layout": "2006-01-02 15:04:05" }
      }
   },
   "logMetas": {
      "log_group_value": "/lab/swmetric/web",
      "log_stream_value": "web"
   }
}
```

```bash

cd ~
./servicewatch-agent-manager-linux-amd64 -action stop -dir ~/swagen
t
./servicewatch-agent-manager-linux-amd64 -action run  -dir ~/swagen
t -collector otelcontribcol_linux_amd64
```

Kubernetes 컨테이너 로그 수집 : Kubernetes Engine > 클러스터 ce-ske 상세 > ServiceWatch 로그 수집 > 수정 > 사용

```bash
cd C:\scpv2lab\advance_observability\monitoring
.\loadgen.ps1 -Rps 20 -Duration 120
```
콘솔 조회 : ServiceWatch > 로그 > 로그 그룹 > /lab/swmetric/web > 로그 스트림 web

error 로 검색해 본다. 필터·집계가 되는가 — 안 된다. 나쁜 로그의 결론

cebastion 접속
```poweshell
cd  C:\scpv2lab\advance_observability\monitoring\terraform
ssh -i mykey.pem rocky@[cebastion_public_ip]
```
- 좋은 로그로 전환(cebastion)
  ```bash
  # Web VS — Bastion 에서
  ./logapp-setup.sh --only-web --log-mode=good

  # API Pod
  kubectl -n logapp patch configmap logapp-config -p '{"data":{"LOG_MODE":"good"}}'
  kubectl -n logapp rollout restart deploy/logapp-api
  ```
  
  -(ceweb)  `log.json` 의 `operators` 를 JSON 한 줄용으로 바꾼다 : `"regex": "^(?P<message>.*)$"` 만 남기고 `timestamp` 제거

  

