# Logging

## Object Storage 버킷 생성
  - 버킷명 : `celog`

## Virtual Server Logging
- 웹서버(ceweb) 접속
  ```powershell
  cd C:\scpv2lab\advance_observability\monitoring\
  ssh -i .\terraform\mykey.pem rocky@[Bastion_Public_IP]
  #Bastion 접속 후
  ssh -i mykey.pem rocky@[ceweb_Private_IP] 
  ```
  
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
- Agent 로그 설정(ceweb)  

    ```bash
    vi ~/swagent/log.json
    ``` 
    ```json
    {
       "fileLog": {
          "include": ["/var/log/logapp/web.log"],
          "operators": { "regex": "^(?P<message>.*)$" }
       },
       "logMetas": {
          "log_group_value": "/lab/swmetric/web",
          "log_stream_value": "web"
       }
    }
    ```
   
    ```bash
    cd ~
    ./servicewatch-agent-manager-linux-amd64 -action stop -dir ~/swagent
    ./servicewatch-agent-manager-linux-amd64 -action run  -dir ~/swagent -collector otelcontribcol_linux_amd64
    ```

- ServiceWatch 로그 그룹 생성
  - 로그 그룹명:  `/lab/swmetric/web`
  - 로그 보관 정책: `30일` 

- 로그 스트림 생성  
  - 로그 그룹: /lab/swmetric/web
  - 로그 스트림명: `web`
  - 원본 파일: `/var/log/logapp/web.log` 

- 부하 생성(PC)   
   ```bash
   cd C:\scpv2lab\advance_observability\monitoring
   .\loadgen.ps1 -Rps 20 -Duration 120
   ```

## Kubernetes Engine Logging
- Kubernetes Engine > 상세 정보 > ServiceWatch 로그 수집 : 사용

## Database Service Logging
- PostgreSQL > 상세 정보 > ServiceWatch 로그 수집 : 사용

## Logging&Audit Trail  
- IAM 정책 생성  
  https://docs.e.samsungsdscloud.com/userguide/management/logging_audit/how_to_guides/trail/#servicewatch
  - 정책명: `TrailLog`
- IAM 역할 생성
  - 역할명: `TrailLogRole`
  - 최대 세션 지속 시간: `1시간`
  - 수행 주체: `서비스`
  - Value: `loggingaudit.samsungsdscloud.com`
  - 정책 연결: `TrailLog`
- Trail 생성
  - Trail명: `cetrail`
  - 대상 리전: `한국 서부1`
  - 저장 버킷 리전: `한국 서부1`
  - 저장 버킷: `celog`
  - 저장 형식: `JSON`
  - ServiceWatch 로그 수집: 사용
    - IAM 역할: `TrailLogRole`

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
 

  

