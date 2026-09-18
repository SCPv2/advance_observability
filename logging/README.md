# Logging

## Object Storage 버킷 생성
  - 버킷명 : `celog`

## Virtual Server Logging

- NTP 설정(ceweb)
   https://docs.e.samsungsdscloud.com/userguide/compute/virtual_server/how_to_guides/ntp/
   
   ```bash
   sudo dnf install chrony -y
   vi /etc/chrony.conf
   ```
   아래 NTP 서버 IP로 설정되어 있는지 확인
   ```conf
   # servers
   server 198.19.0.54 iburst
   ```
   Chronyd 데몬 재시작
   ```bash
   sudo systemctl enable chronyd
   sudo systemctl restart chronyd
   chronyc tracking | grep -E "Reference ID|Leap status"
   date '+%Y-%m-%d %H:%M:%S %Z (%z)'
   ```
-Agent 로그 설정(ceweb)
  Agent 로그 작성
   ```bash
   vi ~/swagent/log.json
   ``` 
   ```json
   {
      "fileLog": {
         "include": ["/var/log/logapp/web.log"],
         "operators": {
            "regex": "^(?P<timestamp>\\S+ \\S+)\\s+(?P<message>.*)$",
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

- ServiceWatch 로그 그룹 생성
   |로그 그룹명|로그 보관 정책|
   |----|----|
   |`/lab/swmetric/web`|30일|

- 로그 스트림 생성
  - 로그 그룹: /lab/swmetric/web 
   |로그 스트림명|원본 파일|
   |`web`|`/var/log/logapp/web.log`|
   |`webaccess`|`/var/log/logapp/web_access.log`|

- 부하 생성(PC)   
   ```bash
   cd C:\scpv2lab\advance_observability\monitoring
   .\loadgen.ps1 -Rps 20 -Duration 120
   ```

## Kubernetes Engine Logging
- Kubernetes Engine > 상세 정보 > ServiceWatch 로그 수집 : 사용

## Database Service Logging
- PostgreSQL > 상세 정보 > ServiceWatch 로그 수집 : 사용

## Network Logging 
- Network Logging > Firewall > Object Storage(celog) 적용
- Network Logging > Security Group > Object Storage(celog) 적용
- Network Logging > NAT > Object Storage(celog) 적용

- Firewall > IGW Firewall, Load Balancer Firewall 로그 사용
- Security Group > ske, ceweb, ceapp, cebastion 로그 사용
- Internet Gateway 로그 사용 

## ServiceWatch 이벤트 

- 이벤트 규칙 생성
  - 이벤트 규칙명: `k8sevent`
  - 이벤트 소스: `Kubernetes Engine`
  - 이벤트 유형: `Node Pool`
  - 적용 이벤트: `모든 이벤트`
  - 적용 자원:`모든 자원`
 

  

