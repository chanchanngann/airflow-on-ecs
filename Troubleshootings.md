### issue #1 - task log failed with No host supplied

##### Error message:
```
requests.exceptions.InvalidURL: Invalid URL 'http://:8793/log/dag_id=dbt_orders/run_id=manual__2026-06-21T07:58:44.858203+00:00/task_id=stg_orders2_run/attempt=1.log': No host supplied
```
##### Why?
Worker does not have a proper `hostname_callable`. Usually, we should have `http://<worker-host>:8793/log/...`
```
Airflow UI/api-server → tries to read worker log → http://<worker-host>:8793/log/...
```
But the URL became
```
http://:8793/log/...
```
That means `<worker-host>` was missing.

So, why the UI was showing `http://:8793`?
Because `remote log` reading/writing was failing during task execution, then UI falls back to served local logs.

=> Need to enable remote logging properly.

##### Check: worker Cloudwatch logs - search for `remote logging`
```
_fetch_remote_logging_conn  
httpx.ConnectError: [Errno -2] Name or service not known
```
This means the **worker subprocess is trying to ask Airflow API/server for the connection**, but it cannot resolve the API/server hostname. It is Airflow 3 task runtime connection lookup. In Airflow 3, the task execution runtime may fetch connections through the Airflow API server / execution API.
```ruby
worker task process
  → fetch aws_default connection from Airflow API/server
  → use it for S3 remote logging
```

Check inside the Airflow container
```ruby
airflow config get-value core execution_api_server_url
# => [warning  ] section/key [core/execution_api_server_url] not found in config [airflow._shared.configuration.parser] loc=parser.py:1360

env | grep AIRFLOW__CORE__EXECUTION_API_SERVER_URL
# => no result
```
The execution api server url should be reachable from worker.

##### Fix #1 - CloudMap
Use Cloud Map for internal worker → apiserver communication.
```ruby
worker ---> Cloud Map ---> apiserver
```
- Use a private internal name for the **Airflow apiserver**, then point workers to that for the Execution API.
	- In terraform, create `resource "aws_service_discovery_service" "airflow_api"`
	- add below to Airflow api server ECS service resource
```ruby
service_registries {
  registry_arn = aws_service_discovery_service.airflow_api.arn
}
```
- apiserver SG: allow worker/scheduler/etc to call apiserver directly
```ruby
from_port = 8080  
to_port = 8080  
ip_protocol = "tcp"  
referenced_security_group_id = aws_security_group.airflow_worker_sg.id
```
- Add `AIRFLOW__CORE__EXECUTION_API_SERVER_URL` to ECS vars.
```
AIRFLOW__CORE__EXECUTION_API_SERVER_URL = "http://airflow-api.airflow.local:8080/execution/"
```
=> ECS containers will resolve Cloud Map DNS inside the VPC.

- restart ECS services
```ruby
aws ecs update-service --cluster airflow-ecs --service airflow_apiserver --force-new-deployment

```

- after deploy, test from inside worker container
```ruby
curl -I http://airflow-api.airflow.local:8080/execution/

# =>
# HTTP/1.1 404 Not Found
# date: Sun, 21 Jun 2026 13:16:33 GMT
# server: uvicorn
# content-length: 22
# content-type: application/json
# airflow-api-version: 2026-04-06
# vary: Accept-Encoding

env | grep AIRFLOW__CORE__EXECUTION_API_SERVER_URL
# AIRFLOW__CORE__EXECUTION_API_SERVER_URL=http://airflow-api.airflow.local:8080/execution/

python - <<'PY'  
from airflow.configuration import conf  
print(conf.get("core", "execution_api_server_url", fallback="MISSING"))  
PY
# http://airflow-api.airflow.local:8080/execution/
```
=> `404` proves that apiserver:8080 is reachable. (worker -> Cloud Map DNS -> apiserver:8080)

##### Check worker cloudwatch log again
```
airflow.sdk.api.client.ServerResponseError: Invalid auth token: Signature verification failed
```
So networking is fixed. The worker can reach apiserver, but the **worker and apiserver are not using the same secret key for Airflow internal API JWT/token signing**.

- Inside **worker** and **apiserver** containers:
```ruby
env | grep AIRFLOW__API__SECRET_KEY # for Airflow 3 internal API authentication
# no value in both containers

env | grep AIRFLOW__API_AUTH__JWT_SECRET # for external API auth
# no value in both containers
```
=> Take care of `AIRFLOW__API__SECRET_KEY` first, since the error points to Airflow 3 internal API authentication.
##### Fix - AIRFLOW__API__SECRET_KEY
- generate the random key
```bash
openssl rand -hex 32
```
- store the secret key in secret manager
- add secret manager ARN to ecs task execution role
- Set the same airflow secret on **all Airflow services**. Fetch secret from secret manager.
```ruby
AIRFLOW__API__SECRET_KEY = "<same-long-random-secret>"
# AIRFLOW__API_AUTH__JWT_SECRET = "<same-long-random-secret>" # SKIP for this time 

```
- then redeploy all airflow services
- verify inside both apiserver and worker containers => if they are identical
```ruby
env | grep AIRFLOW__API__SECRET_KEY
# AIRFLOW__API__SECRET_KEY=xxxxxx

echo -n "$AIRFLOW__API__SECRET_KEY" | sha256sum
# => The hash must be exactly the same.
```

- then trigger new DAG run.

=> Still getting same error.

##### Fix - AIRFLOW__API_AUTH__JWT_SECRET
- repeat the above Fix steps but this time for 
```
AIRFLOW__API_AUTH__JWT_SECRET = var.airflow_secret_key  
AIRFLOW__API_AUTH__JWT_ALGORITHM = "HS512"
```
- Then redeploy **all** services, not only worker.
- verify in both apiserver and worker container:
```ruby
env | grep -E 'AIRFLOW__API__SECRET_KEY|AIRFLOW__API_AUTH__JWT_SECRET|AIRFLOW__API_AUTH__JWT_ALGORITHM'
#AIRFLOW__API_AUTH__JWT_ALGORITHM=HS512
#AIRFLOW__API__SECRET_KEY=xxx
#AIRFLOW__API_AUTH__JWT_SECRET=xxx

```
- Then trigger a fresh DAG run.

=> [FINALLY SUCCESS!!] I can see the task log on airflow UI and also in S3 log bucket.

- expected result
```ruby
- worker -> apiserver /execution/ 
- token signature verified 
- worker fetches aws_default 
- S3 remote log uploads 
- UI reads S3 log 
```

ref: https://airflow.apache.org/docs/apache-airflow/stable/configurations-ref.html#secret-key