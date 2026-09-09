# 클라우드 모니터링

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
  git clone https://github.com/SCPv2/advance_observability.git
  ```

- Samsung Cloud Platform CLI 및 Terraform 환경 설정

  아래 파일을 다운로드해서 작업 디렉토리(C:\scpv2lab)에 저장
  
  CLI 다운로드 : https://docs.e.samsungsdscloud.com/clireference/cli-common/  
  Terraform 다운로드 : https://developer.hashicorp.com/terraform/install

- Terraform 환경 설정 : [Terraform을 통한 인프라 운영 자동화](https://github.com/SCPv2/advance_iac/tree/main/terraform) 참조

## 실습 자원 배포

-  Terraform 실행  
    ```powershell
    cd c:\scpv2lab\advance_observability\monitoring\
    
    terraform init
    terraform validate
    terraform plan
    
    terraform apply --auto-approve
   ``` 
   - 변수 입력
     var.db_password
       Enter a value:  PostgreSQL(DBaaS)의 관리자(labuser)의 암호 임의 입력

     var.user_puplic_ip
       Enter a value: 실습자 PC의 Public IP 주소 입력     
    
   - Key Pair 파일 추출 (mykey.pem)
    ```powershell
    terraform output -raw keypair_private_key > mykey.pem 
    ```
   - Key Pair 파일 권한 수정
   ```powershell 
    icacls mykey.pem /inheritance:r /grant:r "$($env:USERNAME):R"
    ```

## 환경 검토

- Architecture Diagram 검토



- IAM 사용자 목록 및 권한 연결 상태

**&#128906; 사용자 및 정책 구성 목표**

- 사용자 정의 정책
  |정책명|서비스|제어유형|액션|적용자원|인증유형|적용IP|비고|  
  |:-----:|:-----:|:-----|:-----|:-----|:-----|:-----|:-----|    
  |DeveloperAccess|Virtual Server|허용|모든 액션|ceweb,ceapp|인증키|모든 IP|DeveloperGroup 전용|    
  |ExternalDeveloperAccess|Virtual Server|허용|Read, List|ceweb|인증키|외부회사 IP|ExternalDeveloper 전용|
  |DBAccess|PostgreSQL|허용|모든 액션|모든 자원|모든 인증|모든 IP|DBA 전용| 
  |NetworkEngineerAccess|VPC/Firewall/Security Group/DirectConnect|허용|모든 액션|모든 자원|모든 인증|모든 IP|Network Engineer 역할| 
  |NetworkAccessPolicy|모든 서비스|거부|모든 액션|모든 자원|모든 인증|모든 IP(사내 IP 제외)|사내 전직원|  
  |AccessKeyAccessDefault|Identity Access Management|허용|모든 AccessKey 작업, Endpoint List|모든 자원|모든 인증|모든 IP|인증키 인증 사용자|  
  |ConsoleAccessDefault|Resource Manager|허용|Read, List|모든 자원|모든 인증|모든 IP|Console 인증 사용자|  
  |TemporaryKeySetupAccess|Secret Vault, Identity Access Management|허용|모든 액션|모든 자원|모든 인증|모든 IP|임시키 인증 설정용|  

- 기존 주체 수정
  |부서|유형|이름|기존 정책|변경 정책|비고|  
  |:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|   
  |개발팀|사용자|Alex|AdministratorAccess||DeveloperGroup에 포함|   
  |개발팀|사용자|Robert|AdministratorAccess||DeveloperGroup에 포함|  
  |개발팀|사용자|Scott|AdministratorAccess|DBAccess, ConsoleAccessDefault, NetworkAccessPolicy|DeveloperGroup에 포함|  
  |운영팀|사용자|Jeff|AdministratorAccess|AdministratorAccess, NetworkAccessPolicy||  
  |운영팀|사용자|Lonard|AdministratorAccess||사용자를 사용하지 않고 역할(자격증명공급자)로 접근|

- 신규 주체 생성
  |부서|유형|이름|정책|비고| 
  |:-----:|:-----:|:-----:|:-----:|:-----:|  
  |개발팀|그룹|DeveloperGroup|DeveloperAccess, AccessKeyAccessDefault, NetworkAccessPolicy||
  |운영팀|역할|NetworkEngineerRole|NetworkEngineerAccess, NetworkAccessPolicy, ConsoleAccessDefault|자격 증명 공급자로 연결|  
  |외부회사|사용자|ExternalDeveloper|ExternalDeveloperAccess*|| 
   - *ExternalDeveloper의 Secret Vault를 구성할 때 AccessKeyAccessDefault, TemporaryKeySetupAccess, ConsoleAccessDefault 정책 임시 연결
   

## 정책 만들기

**&#128906; Jeff(Cloud Engineer) Console**

- 개발팀(DeveloperGroup)용 정책 만들기
  - 정책명 : `DeveloperAccess`
  - 서비스 : Virtual Server
  - 제어 유형 : 허용 정책
  - 액션 : Create / Delete / List / Read / Update
  - 적용 자원 : 개별 자원 : ceweb, ceapp
  - 인증 유형 : 인증키 인증
  - 적용 IP : 모든 IP

- 외부개발자용 정책 만들기
  - 정책명 : `ExternalDeveloperAccess`
  - 서비스 : Virtual Server
  - 제어 유형 : 허용 정책
  - 액션 : List / Read / Update
  - 적용 자원 : 개별 자원 : ceweb
  - 인증 유형 : 인증키 인증
  - 적용 IP : 실습 PC Public IP(외부회사 IP)

- 사내 IP에서만 접근하게 하는 정책(사내 직원 공통) 만들기
  - 정책명 : `NetworkAccessPolicy`
  - 정책 문서 : ([NetworkAccessPolicy](./policy/NetworkAccessPolicy.json)
   
- DBA(Scott)용 정책 만들기
  - 정책명 : `DBAccess`
  - 정책 문서 : ([DBAccess](./policy/DBAccess.json)) 

- Network Engineer(Leonard)용 정책 만들기
  - 정책명 : `NetworkEngineerAccess`
  - 정책 문서 : ([NetworkEngineerAccess](./policy/NetworkEngineerAccess.json)) 
  
- 인증키 인증 유형 정책과 함께 적용하는 정책 만들기
  - 정책명 : `AccessKeyAccessDefault`
  - 정책 문서 : ([AccessKeyAccessDefault](./policy/AccessKeyAccessDefault.json)) 

- Console 인증 유형 정책과 함께 적용하는 정책 만들기
  - 정책명 : `ConsoleAccessDefault`
  - 정책 문서 : ([ConsoleAccessDefault](./policy/ConsoleAccessDefault.json)) 
  
- 임시키 설정을 위한 정책 만들기
  - 정책명 : `TemporaryKeySetupAccess`
  - 정책 문서 : ([TemporaryKeySetupAccess](./policy/TemporaryKeySetupAccess.json)) 

## 사용자 그룹 생성 및 사용자 연결

**&#128906; Jeff(Cloud Engineer) Console**

- 최소한의 허용 원칙 적용을 위한 정책 조정  
  IAM 정책 - AdministratorAccess - Jeff를 제외한 모든 사용자를 정책에서 제외

- 사용자 그룹 생성
  - 사용자 그룹명 : `DevloperGroup`
  - 사용자 : Alex, Robert
  - 정책 연결 : DeveloperAccess, NetworkAccessPolicy, AccessKeyAccessDefault

**&#128906; Alex(Developer) Console**
 
- Console에서 인증키를 생성

**&#128906; Alex(Developer) : 실습 PC**

- CLI를 위한 환경 설정

```powershell
edit $env:USERPROFILE\.scp\cli-config.json
```

```json
{
     "auth_url": "https://iam.e.samsungsdscloud.com/v1/endpoints",
     "access_key": "Alex의 인증키 access-key 입력",
     "access_secret_key": "Alex의 인증키 access-secret-key 입력",
     "default_scp_region": "kr-west1"
}
```

-  개발자 권한으로 CLI 실행

```powershell
cd c:\scpv2lab\advance_landingzone\iam\

scp-cli virtualserver server show --server_id ceapp_자원_ID

scp-cli virtualserver server show --server_id ceweb_자원_ID

scp-cli vpc vpc show --vpc_id vpc_자원_ID
```

## 사용자 그룹에 기존 사용자 추가(Scott/DBA)

**&#128906; Jeff(Cloud Engineer) Console**

- Scott(DBA)에게 DBAccess 정책 연결

**&#128906; Scott(DBA) Console**

- Console 접근 테스트
  - PostgreSQL(DBaaS)에 접근
  - Virtual Server에 접근

**&#128906; Jeff(Cloud Engineer) Console**

- Scott(DBA)을 개발자 사용자 그룹(DeveloperGroup)에 연결

**&#128906; Scott(DBA) Console**

- Console 접근 테스트
  - PostgreSQL(DBaaS)에 접근
  - Virtual Server에 접근

## 역할(자격 증명 공급자)를 통한 Console 접근(Leonard/Network Engineer)

**&#128906; Jeff(Cloud Engineer) : CEWEB**

```powershell
# ceweb_public_nat_ip는 CEWEB 서버의 Public NAT IP로 변경
ssh -i mykey.pem rocky@ceweb_public_nat_ip 
```
```bash
vi idp_keycloak_install.sh
```
[Keycloak 설치 스크립트](./idp/idp_keycloak_install.sh)를 Copy & Paste

```bash
chmod +x idp_keycloak_install.sh
./idp_keycloak_install.sh
```
- 설치 입력 값
  - Public NAT IP[ceweb]: ceweb 서버의 Public NAT IP 입력
  - Keycloak 관리자 계정 (필수 입력)
    - 관리자 ID: 임의로 입력
    - 관리자 비밀번호: 임의로 입력
  - Keycloak 실습 사용자
    - 사용자 ID [leonard]: 엔터 입력
    - 사용자 비밀번호 (필수 입력): 임의로 입력

설치가 완료된 후 실습 PC에서 실행

```powershell
# ceweb_public_nat_ip는 CEWEB 서버의 Public NAT IP로 변경
curl.exe -f -o keycloak-metadata.xml http://ceweb_public_nat_ip:8080/realms/creative-energy/protocol/saml/descriptor
```

**&#128906; Jeff(Cloud Engineer) Console**

- 자격증명공급자 생성
  - 자격증명공급자명 : `creative-energy`
  - 유형 : SAML
  - 파일 첨부 : 작업 디렉토리에서 다운받은 XML 파일 첨부

- 역할 생성
  - 역할명: `NetworkEngineerRole`  
  - 최대 세션 지속시간: 2시간  
  - 수행주체: 구분 : 자격 증명 공급자 , Value : creative-energy  
  - 정책 연결 : `NetworkEngineerAccess`,`ConsoleAccessDefault`  

**&#128906; Jeff(Cloud Engineer) : CEWEB**

```bash
vi idp_keycloak_config.sh
```
[Keycloak 설정 스크립트](./idp/idp_keycloak_config.sh)를 Copy & Paste

```bash
chmod +x idp_keycloak_config.sh
./idp_keycloak_config.sh
```
- Keycloak 설정
  - SCP Account ID: Samsung Cloud Platform의 Account ID 입력
  - SP Entity ID: 자격 증명 공급자 로그인 URL 중 /의 마지막 마디(SAMLSPcccccc999fff0000b와 같은 형식) 입력
  - 자격 증명 공급자 SRN : 자격 증명공급자의 SRN 입력
  - 역할 SRN : NetworkEngineerRole의 SRN 입력

**&#128906; leonard(Network Engineer) : 실습 PC**

- IdP(Keycloak)를 통한 Samsung Cloud Platform 콘솔 자격 인증

브라우저에 아래의 주소 입력, ceweb_public_nat_ip는 CEWEB 서버의 Public NAT IP로 수정

```url
http://ceweb_public_nat_ip:8080/realms/creative-energy/protocol/saml/clients/scp
```

## 임시키 인증을 통한 Samsung Cloud Platform 접근(외부 개발자)

**&#128906; Jeff(Cloud Engineer) Console**

- 사용자 생성
  - 사용자명: `ExternalDeveloper`
  - 정책 연결: `ExternalDeveloperAccess`,`AccessKeyAccessDefault`,`TemporaryKeySetupAccess`

**&#128906; ExternalDeveloper Console**

- 인증키 생성
  - 만료 기간 : `영구`
  - 보안 설정
    - 인증 방식 : `인증키`
    - 접근 허용 IP: `실습 PC IP`, `10.60.0.0/16`

- Secret Vault 생성
  - Secret명: `externaldeveloperaccess`
  - 유형: SCP Open API Key
  - 인증키: 위에서 생성한 인증키 선택
  - Token 사용 기간 : `30`일
  - 임시키 교체 주기 : `3`시간
  - 접근 허용 IP: `실습 PC IP`, `10.60.0.0/16`

- Secret Vault 생성 후 자원 ID, Token ID, Token Secret을 기록

**&#128906; ExternalDeveloper PC**

```powershell
cd c:\scpv2lab\advance_landingzone\iam\
.\Invoke-ScpApi.ps1 -VaultId "<secretvault_id>" -TokenId "<token_id>" -TokenSecret "<token_secret>" -ServerId "<ceweb_server_id>"
.\Invoke-ScpApi.ps1 -VaultId "<secretvault_id>" -TokenId "<token_id>" -TokenSecret "<token_secret>" -ServerId "<ceapp_server_id>"
```
만약 에러가 발생할 경우 아래 명령을 실행 후 다시 위 명령을 실행

```poweshell
Unblock-File .\Invoke-ScpApi.ps1
```


