# Log Analysis

## Virtual Server Log 검토
Bastion(cebastion)에서 실행
```bash
./logapp-setup.sh --only-web --log-mode=good                       
kubectl -n logapp patch configmap logapp-config -p '{"data":{"LOG_MODE":"good"}}'
kubectl -n logapp rollout restart deploy/logapp-api               
```
WEB서버(ceweb)에서 실행
```bash
sudo cat /proc/$(systemctl show -p MainPID --value logapp-web)/environ | tr '\0' '\n' | grep -E 'LOG_MODE|API_HOST|API_PORT'
curl -s -o /dev/null -w '%{http_code} %{time_total}s\n' localhost:3000/
```
WEB서버 로그 전송 변환
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
ServiceWatch Agent 재기동
```bash
python3 -m json.tool ~/swagent/log.json > /dev/null && echo "json ok"
cd ~
./servicewatch-agent-manager-linux-amd64 -action stop -dir ~/swagent
./servicewatch-agent-manager-linux-amd64 -action run  -dir ~/swagent -collector ./otelcontribcol_linux_amd64
sleep 5; tail -n 3 ~/swagent/otelcol.log                         
```
web_access.log 용 Agent 구성
```bash
mkdir -p ~/swagent-access
cp ~/swagent/agent.json ~/swagent-access/
sed -i 's/"telemetryPort": 8888/"telemetryPort": 8889/' ~/swagent-access/agent.json     
vi ~/swagent-access/log.json
```
```json
{
   "fileLog": {
      "include": ["/var/log/logapp/web_access.log"],
      "operators": { "regex": "^(?P<message>.*)$" }
   },
   "logMetas": {
      "log_group_value": "/lab/swmetric/web",
      "log_stream_value": "webaccess"
   }
}
```
Agent 재기동
```bash
python3 -m json.tool ~/swagent-access/log.json > /dev/null && echo "json ok"
cd ~
./servicewatch-agent-manager-linux-amd64 -action run -dir ~/swagent-access -collector ./otelcontribcol_linux_amd64
sleep 5; tail -n 2 ~/swagent-access/otelcol.log     
```

## 서버에서 로그 검토
실습 PC Powershell에서 실행
```powershell
# 정상 부하 발생
cd C:\scpv2lab\advance_observability\monitoring
.\loadgen.ps1 -Rps 20 -Duration 120
```
Bastion 서버에서 실행
```bash
# 20% 확률로 에러가 나도록 부하앱 조정
~/logapp/faults.sh errors 0.2
```
실습 PC에서 실행
```bash
# 에러가 발생하는 부하 발생
.\loadgen.ps1 -Rps 20 -Duration 60
```
Web서버에서 실행
```bash
# 에러가 발생한 것을 확인
sudo grep '"level":"error"' /var/log/logapp/web.log | tail -n 1 | jq '{status, downstream_status, downstream_pod, trace_id, error_message, stack}'
```
# Bastion 서버에서 실행
```bash
# 부하앱의 에러 발생 해제 및 정상화
~/logapp/faults.sh clear
```
## 콘솔에서 로그 검토
- ServiceWatch 로그 스트림: web, webaccess

## 저장 로그 추적
- DuckDB 설치
  Bastion 서버에서 실행
  ```bash
  curl -fsSL https://install.duckdb.org | sh
  echo 'export PATH="$HOME/.duckdb/cli/latest:$PATH"' >> ~/.bashrc && source ~/.bashrc
  duckdb --version
  ```
  Object Storage 연결
  Bastion 서버에서 실행, `<Access Key>`, `<Secret Key>`는 실제 값으로 대체, 인증키 보안 설정에 Bastion 서버의 Public IP 허용
  ```bash
  duckdb ~/logs.duckdb <<'SQL'
  INSTALL httpfs; LOAD httpfs;
  CREATE OR REPLACE PERSISTENT SECRET celog (
    TYPE s3, KEY_ID '<Access Key>', SECRET '<Secret Key>',
    ENDPOINT 'object-store.private.kr-west1.e.samsungsdscloud.com',
    REGION 'kr-west1', URL_STYLE 'path', USE_SSL true, SCOPE 's3://celog'
  );
  SQL
  chmod 700 ~/.duckdb/stored_secrets; chmod 600 ~/logs.duckdb
  duckdb ~/logs.duckdb -c "SELECT regexp_extract(filename,'s3://celog/([^/]+/[^/-]+)',1) src, count(*) files, sum(size) bytes FROM read_blob('s3://celog/**') GROUP BY 1 ORDER BY 1;"

  nohup duckdb -ui ~/logs.duckdb > ~/duckdb-ui.log 2>&1 &
  ```
- DuckDB 실행
  실습 PC에서 실행
  ```powershell
  # PC — 터널 (이 창은 열어 둔다)
  ssh -i terraform\mykey.pem -L 4213:localhost:4213 rocky@<bastion_public_ip>
  ```
  
  브라우저에서 실행
  ```url
  http://localhost:4213
  ```
 
  뷰설정
  ```bash
  read -p "web 로그 그룹 ID (/lab/swmetric/web): " WEB
read -p "ske 로그 그룹 ID (ce-ske…): " SKE
read -p "pg  로그 그룹 ID (/scp/postgresql/…): " PG
cat > ~/views.sql <<'SQL'
-- Web 앱 로그 (body 안 JSON 을 한 번 더 푼다)
CREATE OR REPLACE VIEW web_log AS
SELECT j.timestamp::TIMESTAMPTZ ts, j.level, j.service, j.host, j.message, j.event, j.trace_id, j.tier, j.method, j.path,
       j.status::INTEGER status, j.latency_ms::DOUBLE latency_ms, j.downstream_ms::DOUBLE downstream_ms, j.self_ms::DOUBLE self_ms,
       j.downstream_status::INTEGER downstream_status, j.downstream_pod, j.user_id, j.error_message, j.stack
FROM (SELECT from_json(body, '{"timestamp":"VARCHAR","level":"VARCHAR","service":"VARCHAR","host":"VARCHAR","message":"VARCHAR","event":"VARCHAR","trace_id":"VARCHAR","tier":"VARCHAR","method":"VARCHAR","path":"VARCHAR","status":"VARCHAR","latency_ms":"VARCHAR","downstream_ms":"VARCHAR","self_ms":"VARCHAR","downstream_status":"VARCHAR","downstream_pod":"VARCHAR","user_id":"VARCHAR","error_message":"VARCHAR","stack":"VARCHAR"}') j
      FROM read_json_auto('s3://celog/servicewatch/<web>_*.json') WHERE body LIKE '{%');

-- Web 액세스 로그 (같은 파일의 공백 구분 줄)
CREATE OR REPLACE VIEW access_log AS
SELECT regexp_extract(body, '^(\S+) - (\S+) \[([^\]]+)\] "(\S+) (\S+) [^"]*" (\d+) (\d+) (\d+) (\S+)$',
                      ['ip','user','ts','method','path','status','bytes','latency_ms','trace_id']) f
FROM read_json_auto('s3://celog/servicewatch/<web>_*.json') WHERE body NOT LIKE '{%';

-- PostgreSQL 서버 로그: SQL 문과 trace 주석
CREATE OR REPLACE VIEW pg_log AS
SELECT timezone('Asia/Seoul', strptime(regexp_extract(body, '^(\S+ \S+) KST', 1), '%Y-%m-%d %H:%M:%S')) ts,
       regexp_extract(body, '\] (\S+)@', 1) db_user,
       regexp_extract(body, '\)(LOG|ERROR|FATAL|WARNING|DETAIL|STATEMENT):', 1) kind,
       regexp_extract(body, 'trace=([0-9a-f]+)', 1) trace_id,
       regexp_extract(body, 'label=(\w+)', 1) label,
       regexp_extract(body, '(LOG|ERROR|FATAL|WARNING|DETAIL|STATEMENT):\s+(.*)$', 2) text
FROM read_json_auto('s3://celog/servicewatch/<pg>_*.json');

-- K8s API 감사: 누가 어떤 kubectl 을 했나
CREATE OR REPLACE VIEW ske_audit AS
SELECT json_extract_string(body,'$.requestReceivedTimestamp')::TIMESTAMPTZ ts,
       json_extract_string(body,'$.verb') verb, json_extract_string(body,'$.user.username') who,
       json_extract_string(body,'$.requestURI') uri, json_extract(body,'$.responseStatus.code')::INTEGER code
FROM read_json_auto('s3://celog/servicewatch/<ske>_*.json') WHERE body LIKE '{"kind":"Event","apiVersion":"audit.k8s.io%';

-- K8s Event: Killing · Scheduled · Pulled · BackOff · OOMKilled
CREATE OR REPLACE VIEW ske_events AS
SELECT coalesce(json_extract_string(body,'$.lastTimestamp'), json_extract_string(body,'$.eventTime'), json_extract_string(body,'$.metadata.creationTimestamp'))::TIMESTAMPTZ ts,
       json_extract_string(body,'$.type') type, json_extract_string(body,'$.reason') reason,
       json_extract_string(body,'$.involvedObject.kind') || '/' || json_extract_string(body,'$.involvedObject.name') object,
       json_extract_string(body,'$.message') message
FROM read_json_auto('s3://celog/servicewatch/<ske>_*.json') WHERE json_extract_string(body,'$.reason') IS NOT NULL;

-- 경로 B
CREATE OR REPLACE VIEW fw_log  AS SELECT * FROM read_csv('s3://celog/LOG/FW/FW_IGW_ce-vpc-*/*/*.csv', header = true);
CREATE OR REPLACE VIEW nat_log AS SELECT * FROM read_csv('s3://celog/LOG/NAT/*/*/*.csv', header = true);
CREATE OR REPLACE VIEW sg_deny AS SELECT * FROM read_csv('s3://celog/LOG/SG/Deny/*/*.csv', header = true, ignore_errors = true);

SELECT 'web_log' v, count(*) n FROM web_log UNION ALL SELECT 'pg_log', count(*) FROM pg_log
UNION ALL SELECT 'ske_audit', count(*) FROM ske_audit UNION ALL SELECT 'ske_events', count(*) FROM ske_events
UNION ALL SELECT 'fw_log', count(*) FROM fw_log UNION ALL SELECT 'nat_log', count(*) FROM nat_log;
SQL
sed -i "s/<web>/$WEB/g; s/<ske>/$SKE/g; s/<pg>/$PG/g" ~/views.sql
grep -c '<' ~/views.sql | grep -q '^0$' && echo "IDs OK" || echo "치환 안 된 자리표시자가 있음"
duckdb ~/logs.duckdb < ~/views.sql
```





## Quick Query 
  - Security Group 생성
  - Security Group명: `ceqqsg`

- Quick Query 생성
  - Quick Query 명: `ceqq`
  - 도메인 설정: `ceqq.test`
  - 쿼리 엔진 타입: 공용 , 엔진 Spec : Auto Scaling 선택 안함
  - 최대 동시 실행 쿼리수: 32
  - Data Service Console 연결 도메인 설정: `dsc.test`
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
  (Load Balancer(ceqq) Public NAT IP)  ceqq.ceqq.test  
  (Load Balancer(ceqq) Public NAT IP)  ceqq-console.dsc.test  
  (Load Balancer(ceqq) Public NAT IP)  ceqq-iam.dsc.test  

- Quick Query 접속
  ```url
  https://ceqq.test
