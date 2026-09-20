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

## 로그 검토
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
Bastion 서버에서 실행
```bash
# 부하앱의 에러 발생 해제 및 정상화
~/logapp/faults.sh clear
```
콘솔에서 로그 검토
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
   ```
- 뷰 정의
  Bastion 서버에서 실행, 콘솔에서 로그 그룹 ID 조회 후 입력
  ```bash
  read -p "web 로그 그룹 ID (/lab/swmetric/web): " WEB
  read -p "ske 로그 그룹 ID (ce-ske…): " SKE
  read -p "pg  로그 그룹 ID (/scp/postgresql/…): " PG
  echo "web=$WEB ske=$SKE pg=$PG"
  ```
  Bastion 서버에서 실행
   ```bash
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
          regexp_extract(body, 'label=(\w+)', 1) sql_label,
          regexp_extract(body, '(LOG|ERROR|FATAL|WARNING|DETAIL|STATEMENT):\s+(.*)$', 2) log_text
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
          json_extract_string(body,'$.type') ev_type, json_extract_string(body,'$.reason') reason,
          json_extract_string(body,'$.involvedObject.kind') || '/' || json_extract_string(body,'$.involvedObject.name') obj,
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
- 매크로 블럭 정의
  ```bash
  duckdb ~/logs.duckdb <<'SQL'
  -- ① 감지: 분 단위 SLI 시계열, 막대로
  CREATE OR REPLACE MACRO sli_timeline(t0, t1) AS TABLE
  SELECT date_trunc('minute', ts) m, count(*) n,
         sum(status >= 500)::INT e5xx,
         round(quantile_cont(latency_ms, 0.95)) p95,
         bar(quantile_cont(latency_ms, 0.95), 0, 2000, 30) p95_bar
  FROM web_log WHERE event = 'request.complete' AND ts BETWEEN t0::TIMESTAMPTZ AND t1::TIMESTAMPTZ
  GROUP BY 1 ORDER BY 1;

  -- ② 국소화: 기준 창(b0~b1) 대비 문제 창(a0~a1) 에서 튄 (차원, 값)
  CREATE OR REPLACE MACRO whatchanged(b0, b1, a0, a1) AS TABLE
  WITH w AS (
    SELECT *, CASE WHEN ts BETWEEN a0::TIMESTAMPTZ AND a1::TIMESTAMPTZ THEN 'a' WHEN ts BETWEEN b0::TIMESTAMPTZ AND b1::TIMESTAMPTZ THEN 'b' END win
    FROM web_log WHERE event = 'request.complete'),
  d AS (
    SELECT 'path' dim, path val, latency_ms, status, win FROM w WHERE win IS NOT NULL
    UNION ALL SELECT 'pod', downstream_pod, latency_ms, status, win FROM w WHERE win IS NOT NULL
    UNION ALL SELECT 'user', user_id, latency_ms, status, win FROM w WHERE win IS NOT NULL
    UNION ALL SELECT 'status', status::VARCHAR, latency_ms, status, win FROM w WHERE win IS NOT NULL)
  SELECT dim, val,
         sum(win='b')::INT n_before, sum(win='a')::INT n_after,
         round(quantile_cont(latency_ms, 0.95) FILTER (win='b')) p95_before,
         round(quantile_cont(latency_ms, 0.95) FILTER (win='a')) p95_after,
         round(quantile_cont(latency_ms, 0.95) FILTER (win='a') / nullif(quantile_cont(latency_ms, 0.95) FILTER (win='b'), 0), 1) p95_ratio,
         round(100.0 * sum(win='a' AND status >= 500) / nullif(sum(win='a'), 0), 1) err_pct_after
  FROM d GROUP BY 1, 2 HAVING n_after >= 20 ORDER BY p95_ratio DESC NULLS LAST, err_pct_after DESC LIMIT 12;

  -- ④ 변화: 모든 소스를 한 줄 형식으로, 시간 창 안의 사건
  CREATE OR REPLACE VIEW events AS
    SELECT ts, 'web' src, level sev, coalesce(downstream_pod, '-') entity, message log_text FROM web_log WHERE level IN ('warn', 'error')
    UNION ALL SELECT ts, 'k8s-event', ev_type, obj, reason || ': ' || message FROM ske_events
    UNION ALL SELECT ts, 'k8s-audit', verb, who, uri FROM ske_audit WHERE verb IN ('create', 'delete', 'patch', 'update') AND who NOT LIKE 'system:%'
    UNION ALL SELECT ts, 'pg', kind, db_user, log_text FROM pg_log WHERE kind IN ('ERROR', 'FATAL', 'WARNING')
    UNION ALL SELECT eventtimestamp, 'firewall', action, srcip || '→' || dstip || ':' || dstport, coalesce(policyname, '') FROM fw_log WHERE action = 'deny' AND srcip LIKE '10.%'
    UNION ALL SELECT eventtimestamp, 'sg-deny', verdict, nw_src || '→' || nw_dst || ':' || tp_dst, direction FROM sg_deny WHERE nw_proto = 6;
  CREATE OR REPLACE MACRO around(t0, t1) AS TABLE
  SELECT ts, src, sev, entity, left(log_text, 100) log_text FROM events
  WHERE ts BETWEEN t0::TIMESTAMPTZ - INTERVAL 5 MINUTE AND t1::TIMESTAMPTZ ORDER BY ts;

  -- ⑤ 증명: trace_id 하나로 Web → DB
  CREATE OR REPLACE MACRO trace(tid) AS TABLE
  SELECT ts, 'web' tier, path || ' ' || status || ' ' || latency_ms || 'ms (api+db ' || downstream_ms || 'ms, pod ' || downstream_pod || ')' detail FROM web_log WHERE trace_id = tid
  UNION ALL SELECT ts, 'db', sql_label || ': ' || log_text FROM pg_log WHERE trace_id = tid
  ORDER BY ts;
  SQL
  ```
- 매크로 생성 확인 — 소스별 사건 수와 매크로 이름 4개
  ```bash
  duckdb ~/logs.duckdb -c "SELECT src, count(*) n FROM events GROUP BY 1 ORDER BY 1;" -c "SELECT function_name FROM duckdb_functions() WHERE function_name IN ('sli_timeline','whatchanged','around','trace');"
  ```

- DuckDB UI 
  Bastion 에서 실행(백그라운드)
  ```bash
  nohup sh -c 'tail -f /dev/null | duckdb -ui ~/logs.duckdb' > ~/duckdb-ui.log 2>&1 &
  sleep 3; ss -ltn | grep 4213      # LISTEN … :4213
  ```
  실습 PC에서 실행
  ```powershell
  ssh -i terraform\mykey.pem -L 4213:[::1]:4213 rocky@<bastion_public_ip>
  ```
  브라우저에서 `http://localhost:4213`
  
  브라우저에서 실행
  ```url
  http://localhost:4213
  ```
 
## 정상 부하 로그 생성
- 정상 부하  발생
   WEB서버에서 실행
   ```bash
   ~/logapp/faults.sh clear
   ```
   Bastion 서버에서 실행
   ```powershell
   .\loadgen.ps1 -Rps 20 -Duration 300
   ```
- 로그 그룹 내보내기
  - /log/swmetric/web
  - PostgreSQL
  - SKE
