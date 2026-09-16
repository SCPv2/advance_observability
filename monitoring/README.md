# Monitoring

## 실습 환경 구성

- 작업 디렉토리 생성 및 작업 환경 가져오기

  작업 디렉토리 만들기
  ```powershell
  mkdir c:\scpv2lab
  cd c:\scpv2lab
  ```

  c:\scpv2lab을 사용자 PATH에 등록
  ```powershell
  $d='C:\scpv2lab'; $p=[Environment]::GetEnvironmentVariable('Path','User'); if($p -split ';' -notcontains $d){[Environment]::SetEnvironmentVariable('Path',($p.TrimEnd(';')+';'+$d),'User')}; $env:Path+=";$d"
  ```

  Advance Observability 실습 챕터 실습 파일 가져오기
  ```powershell
  cd c:\scpv2lab
  git clone https://github.com/SCPv2/advance_observability.git
  ```

- 실습 도구 설정
  - Samsung Cloud Platform CLI
    - 다운로드 주소 : https://docs.e.samsungsdscloud.com/clireference/cli-common/
    - 작업 디렉토리(C:\scpv2lab)에 저장
    - 환경 설정 : https://docs.e.samsungsdscloud.com/clireference/cli-common/

  - Terraform
    - 다운로드 주소 : https://developer.hashicorp.com/terraform/install
    - 작업 디렉토리(C:\scpv2lab)에 저장
    - 환경 설정 : [Terraform을 통한 인프라 운영 자동화](https://github.com/SCPv2/advance_iac/tree/main/terraform) 참조

  - Node.js
    - 설치 파일 주소 : https://nodejs.org/ko/download

## 실습 자원 배포
-  Terraform 실행  
    ```powershell
    cd  C:\scpv2lab\advance_observability\monitoring\terraform
    
    terraform init
    terraform validate
    terraform plan
    
    terraform apply --auto-approve
   ```
   - 변수 입력
      var.my_public_ip
        Enter a value: 실습자 PC의 Public IP 주소 입력

- 인증키 생성
  
- Container Registry 생성
  - 레지스트리명 : `cescr`
    - 엔드포인트 : 프라이빗 : 사용 : cebastion, ce-ske
  - 리포지토리명 : `logapp`

## 실습 도구 구성

- 실습 파일 다운로드 및 압축해제  
  강의 게시판에서 압축파일 다운로드 및 해제
  - 압축파일명 : observability_lab.zip
  - 다운로드 경로 : `C:\scpv2lab\advance_observability\monitoring\`
  ```powershell
  cd C:\scpv2lab\advance_observability\monitoring\

  Expand-Archive -Path .\observability_lab.zip -DestinationPath C:\scpv2lab\advance_observability\monitoring -Force
  ```

- Kubernetes Engine kubeconfig 다운로드
  - 다운로드 위치 : C:\scpv2lab\advance_observability\monitoring\kubeconfig

- Bastion Server 접속 및 서버 설정 파일 전송
  ```powershell
  cd C:\scpv2lab\advance_observability\monitoring
  .\local-setup.ps1
  ```
  ```bash
  ./logapp-setup.sh
  ```
  - Access Key: 사용자 인증키 입력
  - Secret Key: 사용자 인증키 입력
  - SCR 프라이빗 엔드포인트: Container Registry의 프라이빗 엔드포인트 URL

- Load Balancer Firewall 규칙입력
  |	출발지|목적지|서비스|방향	|
  |:----:|:----:|:----:|:----:|
  |10.10.1.0/24|Service IP|TCP *3000*|Outbound|
  |Source NAT IP|10.10.2.0/24|TCP *30000*|Inbound|
  |헬스 체크 IP|10.10.2.0/24|TCP *30000*|Inbound|

## 환경 검토
- Architecture Diagram 검토

## 모니터링 가능 자원 식별
- 서비스 부하 생성
  ```powershell
  cd C:\scpv2lab\advance_observability\monitoring
  .\loadgen.ps1 -Rps 1000 -Duration 300   
  ```
- Service Watch 대시보드 생성
  대시보드명: `Creative_Energy`
  - 개별 위젯 추가
    - Virtual Server
      - CPU Usage: ceweb
      - 시간: 1시간
      - 통계: 최대
      - 집계기간: 5분
- 모니터링 지표 확인
  - WEB계층 부하 확인
    - Virtual Server
    - VPC Internet Gateway
  - APP계층 부하 확인
    - Kubernetes Engine node
    - Load Balancer
    - File Storage
  - DB계층  부하 확인
    - PostgreSQL(DBaaS) 
## 세부 모니터링 구성
- Virtual Server : 세부모니터링 활성화  
  5분 후 실행
  ```powershell
  cd C:\scpv2lab\advance_observability\monitoring
  .\loadgen.ps1 -Rps 1000 -Duration 60   
  ```
## 사용자 정의 지표 구성
- ServiceWatch Agent를 위한 사전 환경 설정([참고 문서](https://docs.e.samsungsdscloud.com/userguide/management/service_watch/how_to_guides/service_watch_agent/#configuration))
  - Security Group 규칙 추가 : Outbound / TCP / 443 / [ServiceWatch OpenAPI Endpoint IP 주소](https://docs.e.samsungsdscloud.com/userguide/management/service_watch/how_to_guides/service_watch_agent/#main)
  - Internet Gateway Firewall 규칙 : Outbound / TCP / 443 / Allow / 출발지 주소(ceweb Private IP(`10.0.1.11`)) / 목적지 주소([ServiceWatch OpenAPI Endpoint IP 주소](https://docs.e.samsungsdscloud.com/userguide/management/service_watch/how_to_guides/service_watch_agent/#main))

- 인증키 보안 설정
  보안 설정 : WEB서버(ceweb)의 Public NAT IP 등록

- Node Exporter 구성
    ```poweshell
    # Bastion 서버에 SSH 접속되어 있지 않을 경우
    cd C:\scpv2lab\advance_observability\monitoring\terraform
  
    ssh -i mykey.pem rocky@[cebastion Public IP]
    ```

  WEB서버(ceweb)에 접속
    ```bash
    ssh -i mykey.pem rocky@[ceweb Private IP]
    ```
  Node Exporter 다운로드
    ```bash
    sudo useradd --no-create-home --shell /bin/false node_exporter
    cd /tmp
    curl -fsSLO https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
    sudo tar -xzf node_exporter-1.7.0.linux-amd64.tar.gz -C /usr/local/bin --strip-components=1 node_exporter-1.7.0.linux-amd64/node_exporter
    sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
    ```
  Node Exporter 설정
    ```bash
    sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<'EOF'
    [Unit]
    Description=Prometheus Node Exporter
    Wants=network-online.target
    After=network-online.target
  
    [Service]
    User=node_exporter
    Group=node_exporter
    Type=simple
    ExecStart=/usr/local/bin/node_exporter \
      --web.listen-address=:9200 \
      --collector.disable-defaults \
      --collector.meminfo \
      --collector.filesystem \
      --collector.loadavg
  
    Restart=on-failure
  
    [Install]
    WantedBy=multi-user.target
    EOF
    ```

  Node Exporter 실행 
    ```bash
    sudo systemctl daemon-reload
    sudo systemctl enable --now node_exporter
    curl -s http://localhost:9200/metrics | grep node_memory_MemAvailable
    ```
- ServiceWatch Agent 구성
  
  ServiceWatch <Agent 다운로드 URL> 확인  
    ServiceWatch 콘솔 > Service Home > 시작 위젯

  ServiceWatch Agent 다운로드
    ```bash  
    # wget이 없을 경우 실행
    sudo dnf install wget unzip -y
  
    wget "<Agent 다운로드 URL>" -O ServiceWatch_Agent.zip
    unzip ServiceWatch_Agent.zip
    chmod +x otelcontribcol_linux_amd64 servicewatch-agent-manager-linux-amd64
    ```
  
  ServiceWatch Agent 설정
  실습 설정용 디렉토리 생성 및 파일 복사, log.json은 Logging 차시에서 구성하므로 삭제
    ```bash
    mkdir -p ~/swagent && cp os-metrics-min-examples/*.json ~/swagent/
    rm ~/swagent/log.json         
    ```
  agent.json 설정
    ```bash
    vi ~/swagent/agent.json
    ```
     아래를 참조해서 작성
       "namespace": `"swmetric/web"`  
       "accessKey": "인증키 <Access Key>",  
       "accessSecret": "인증키 <Secret Key>",  
       "resourceId": "<ceweb 자원 ID>",  
       "openApiEndpoint": `"https://servicewatch.kr-west1.e.samsungsdscloud.com"`,  
       "telemetryPort": 8888

  metric.json 설정  
    ```bash
    vi ~/swagent/metric.json
    ```
     아래 json을 참조해서 작성, `targets`을 9200 으로 수정 (예시는 9100, 우리 Node Exporter 는 9200)  
    ```json
    {
       "prometheus": {
          "scrape_configs": { "targets": ["localhost:9200"], "jobName": "node-exporter" }
       },
       "metricMetas": [
          { "metricName": "node_memory_MemAvailable_bytes", "dimensions": [["resource_id"]], "unit": "Bytes",
            "aggregationMethod": "SUM", "descriptionKo": "가용 메모리", "descriptionEn": "node memory available bytes" },
          { "metricName": "node_memory_MemTotal_bytes",     "dimensions": [["resource_id"]], "unit": "Bytes",
            "aggregationMethod": "SUM", "descriptionKo": "전체 메모리", "descriptionEn": "node memory total bytes" },
          { "metricName": "node_filesystem_avail_bytes",    "dimensions": [["mountpoint"]],  "unit": "Bytes",
            "aggregationMethod": "SUM", "descriptionKo": "파일시스템 여유", "descriptionEn": "node filesystem available bytes" }
       ]
    }
    ```
  Agent 실행
    ```bash
    cd ~
    ./servicewatch-agent-manager-linux-amd64 -action run  -dir ~/swagent -collector otelcontribcol_linux_amd64
    ```
  Agent 중지(필요시)
    ```bash
    cd ~
    ./servicewatch-agent-manager-linux-amd64 -action stop -dir ~/swagent
    ```
- 부하 생성
  실습 PC에서 실행
    ```powershell
    cd C:\scpv2lab\advance_observability\monitoring
    .\loadgen.ps1 -Rps 1000 -Duration 300   
    ```
- 사용자 정의 지표 확인 및 대시보드에 지표 추가

## 경보 생성
- 경보 정책명: `CPU_Average_Alert`
- 지표 선택: Virtual Server / ceweb / 최대 / 1분
- 평가 범위: 300
- 통계: 최대
- 조건 연산자: `>=`
- 임계값: `20`
- 경보 단계: Low
- 알림 수신자: 등록된 사용자 선택 
