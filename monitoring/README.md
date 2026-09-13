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
    cd  C:\scpv2lab\advance_obsevability\monitoring\terraform
    
    terraform init
    terraform validate
    terraform plan
    
    terraform apply --auto-approve
   ```
   - 변수 입력
      var.my_public_ip
        Enter a value: 실습자 PC의 Public IP 주소 입력

- 인증키 생성

- Object Storage 생성
  - 버킷명 : celog
    
- Container Registry 생성
  - 레지스트리명 : `cescr`
    - 엔드포인트 : 프라이빗 : 사용 : cebastion, ce-ske
  - 리포지토리명 : `logapp`

## 실습용 애플리케이션 구성

- 실습 파일 다운로드 및 압축해제
  강의 게시판에서 압축파일 다운로드 및 해제
  - 압축파일명 : observability_lab.zip
  - 다운로드 경로 : `C:\scpv2lab\advance_obsevability\monitoring\`
  ```powershell
  cd C:\scpv2lab\advance_obsevability\monitoring\

  Expand-Archive -Path .\observability_lab.zip -DestinationPath C:\scpv2lab\advance_obsevability\monitoring -Force
  ```

- Kubernetes Engine kubeconfig 다운로드
  - 다운로드 위치 : C:\scpv2lab\advance_obsevability\monitoring\kubeconfig

- Bastion Server 접속 및 서버 설정 파일 전송
  ```powershell
  cd C:\scpv2lab\advance_obsevability\monitoring
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
  cd C:\scpv2lab\advance_obsevability\monitoring
  
  .\loadgen.ps1 -Rps 3000 -Duration 300 
  ```

- 모니터링 지표 확인
  - WEB계층 부하 확인
    - Virtual Server
    - VPC Internet Gateway
  - APP계층 부하 확인
  - VPC Internet 

## 모니터링 가능 자원 식별

- 서비스 부하 생성
  ```powershell
  cd C:\scpv2lab\advance_obsevability\monitoring
  
  .\loadgen.ps1 -Rps 3000 -Duration 300                          # web_public_ip:3000, 20 rps, 300초
  ```
  앞 명령 실행 후 5분 뒤 실행
  ```powershell
  cd C:\scpv2lab\advance_obsevability\monitoring
  .\loadgen.ps1 -Rps 3000 -Duration 30   
  ```
  앞 명령 실행 후 5분 뒤 실행
  ```powershell
  cd C:\scpv2lab\advance_obsevability\monitoring
  .\loadgen.ps1 -Rps 3000 -Duration 300   
  ```
