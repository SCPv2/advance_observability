# Log Analysis

- Security Group 생성
  - Security Group명: `ceqqsg`

- Quick Query 생성
  - Quick Query 명: `ceqq`
  - 도메인 설정: `ceqq.test`
  - 쿼리 엔진 타입: 공용 , 엔진 Spec : Auto Scaling 선택 안함
  - 최대 동시 실행 쿼리수: 32
  - Data Service Console 연결 도메인 설정: `ceqq.dsc.test`
  - Host Alias: 사용안함
  - 클러스터명: `ceqqk8s`
  - 퍼블릭 엔드포인트 엑세스 : 사용 : 실습 PC의 Public IP 주소
  - VPC: 
  - 서브넷:
  - Security Group: 
  - File Storage 설정: 기본 Volume (NFS): 
  - 노드 풀 구성(고정)
  - 노드 수: `4`
  - 나머지 옵션은 기본값으로 설정

- 네트워크 트래픽 제어 규칙 구성
  https://docs.e.samsungsdscloud.com/userguide/analytics/quick_query/how_to_guides/#quick-query-connect

- Ingress Controller 생성
  - ceqqk8s 클러스터에서 퍼블릭 엔드포인트의 k8s 관리자 kubeconfig 파일을 다운로드
    C:\scpv2lab\advance_observability\monitoring\kubeconfig 디렉토리에 ceqqk8s.yaml로 저장
  ```powershell
  cd C:\scpv2lab\advance_observability\monitoring\kubeconfig
  & kubectl --kubeconfig ceqqk8s.yaml -n qq-ns patch svc qq-ceqq-ingress-nginx-controller --type=json -p='[{"op":"remove","path":"/spec/ports/0/appProtocol"},{"op":"remove","path":"/spec/ports/1/appProtocol"}]'
  & kubectl --kubeconfig ceqqk8s.yaml -n qq-ns get svc qq-ceqq-ingress-nginx-controller -w
  ```

- Hosts 파일 변경
  관리자 권한으로 C:\Windows\System32\drivers\etc\hosts 파일에 아래 설정 등록
  (Load Balancer(ceqq) Public NAT IP)  ceqq.test
  (Load Balancer(ceqq) Public NAT IP)  ceqq-console.dsc.test
  (Load Balancer(ceqq) Public NAT IP)  ceqq-iam.dsc.test

- Quick Query 접속
  ```url
  https://ceqq.test
  ```
  ID: `admin`
  Password: `admadm1!`
