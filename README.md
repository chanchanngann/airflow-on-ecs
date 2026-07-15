# Airflow on AWS ECS Fargate

This exercise deploys Apache Airflow on AWS ECS Fargate using the Celery Executor and Terraform. The objective is to evaluate a scalable Airflow architecture that supports distributed task execution, Git-based DAG deployment while maintaining a fully containerized and serverless infrastructure.

Finally, a simple dag is deployed on Airflow to integrate dbt for data transformation in Snowflake.
## Architecture Goals
- Deploy Airflow 3.2 on ECS Fargate  
- Scale task execution using Celery Executor
- Enable Git-based DAG deployment workflow
- Store DAG repo persistently on Amazon EFS  
- Provision all infrastructure with Terraform  
- Separate Airflow services into independent ECS tasks:  
	- API Server  
	- Scheduler  
	- Worker(s)
	- Triggerer  
	- DAG Processor  
- Integrate dbt for data transformation in Snowflake

![architecture](images/01_airflow_on_ecs.png)
### Building Blocks
- Application Load Balancer (ALB) in public subnets for Airflow UI access  
- Internet Gateway and NAT Gateway for internet connectivity  
- ECS Fargate services deployed in private subnets  
- Amazon RDS PostgreSQL as the Airflow metadata database  
- Amazon ElastiCache Redis as Celery broker and result backend  
- Amazon S3 for Airflow remote task logs  
- Amazon CloudWatch for ECS and Airflow monitoring  
- AWS Secrets Manager for credentials and application secrets  
- AWS Systems Manager Session Manager (SSM) for container troubleshooting  
- AWS Cloud Map for service discovery between Airflow components and Gitea  
- Amazon EFS for persistent Gitea storage  
- AWS Certificate Manager (ACM) for HTTPS certificates

## Execution flow
```ruby
# --- Stage 1 ---
- Set up networking (vpc, subnets)

# --- Stage 2 ---
- Set up bastion host
- Build custom image in bastion host
- Push the image to ECR
   
# --- Stage 3 ---
- Create RDS (airflow metadata DB)
- Create Redis (Celery broker)
- Create ECS cluster
- Create & Run airflow-init ECS task (one-off task)
   
# --- Stage 4 ---
- Create ECS Service for Gitea & IAM Roles
- Create ECS Services for Airflow & IAM Roles
	- 5 long-running ECS services
		airflow-api-server  
		airflow-scheduler  
		airflow-worker  
		airflow-triggerer  
		airflow-dag-processor
- Create EFS for Gitea container (mount volume for dags)
- Set up CloudMap for network communication within ECS cluster
- Set up GitDagBundle for Airflow syncing with Gitea repo
- Create ALB, target groups & listener rules
  
# --- Stage 5 ---
- Test push dag to Gitea
- Test dbt + Snowflake pipeline on airflow
```
---
### Stage 1 - Set up networking

Set up the base components: vpc, subnets, s3 gateway endpoint and bastion host.
```ruby
terraform init

terraform apply -target=aws_instance.bastion --auto-approve
terraform apply -target=aws_iam_instance_profile.bastion_instance_profile --auto-approve
terraform apply -target=aws_eip.bastion --auto-approve

terraform apply -target=aws_vpc_security_group_ingress_rule.bastion_allow_ssh --auto-approve
terraform apply -target=aws_vpc_security_group_egress_rule.bastion_allow_https --auto-approve
terraform apply -target=aws_vpc_security_group_egress_rule.bastion_allow_http --auto-approve
terraform apply -target=aws_vpc_security_group_egress_rule.bastion_allow_s3_gateway --auto-approve
terraform apply -target=aws_vpc_security_group_egress_rule.bastion_allow_rds --auto-approve

# access ecr
terraform apply -target=aws_iam_role_policy.access_ecr --auto-approve
```

### Stage 2- Set up bastion and push the images to ECR

1. SSH into bastion host and create folder `airflow`
```
airflow/
 ├── Dockerfile
 ├── config/
 │   ├── airflow_init.sh 
```
2. Create Dockerfile.
3. Create entry scripts `config/airflow_init.sh` which will be baked into Dockerfile.
4. build the Docker image for Airflow
```ruby
docker build . -f Dockerfile --pull --tag airflow-custom:1.0
```
5. Create ECR repo
```ruby
terraform apply -target=aws_ecr_repository.airflow
terraform apply -target=aws_ecr_lifecycle_policy.airflow_lifecycle
```
6. authenticate docker to ECR (use the terraform output for ecr repo url)
```ruby
aws ecr get-login-password | docker login \  
--username AWS \  
--password-stdin \  
123456789.dkr.ecr.xxx.amazonaws.com/airflow-ecr
```
7. Push the custom Airflow image to ECR
```ruby
#  tag your built image for ECR
docker tag airflow-custom:1.0 \
123456789.dkr.ecr.xxx.amazonaws.com/airflow-ecr:1.0

# push image
docker push \
123456789.dkr.ecr.xxx.amazonaws.com/airflow-ecr:1.0
```
8. Again, repeat  steps 5 - 7 for Gitea image
```ruby
terraform apply -target=aws_ecr_repository.gitea --auto-approve
terraform apply -target=aws_ecr_lifecycle_policy.gitea_lifecycle --auto-approve

aws ecr get-login-password | docker login \
--username AWS \
--password-stdin \
123456789.dkr.ecr.xxx.amazonaws.com/gitea-ecr

# 1.26.2 is the latest version as of 20260609
docker pull gitea/gitea:1.26.2

# tag the image
docker tag \
gitea/gitea:1.26.2 \
123456789.dkr.ecr.xxx.amazonaws.com/gitea-ecr:1.26.2

# push to ECR
docker push \
123456789.dkr.ecr.xxx.amazonaws.com/gitea-ecr:1.26.2
```

![ecr](images/02_ecr.png)

---
### Stage 3 - Set up RDS, Redis and run airflow-init task

1. Create RDS
```ruby
terraform apply -target=aws_db_instance.airflow_db
terraform apply -target=aws_vpc_security_group_ingress_rule.rds_allow_airflow_init_sg  --auto-approve
```
2. Test connection to RDS
   
- register ssh config in `~/.ssh/config`
```ruby
Host bastion
  HostName <bastion_public_ip>
  User ec2-user
  IdentityFile ~/.ssh/<key_pair>.pem

Host airflow-db
	HostName <bastion_public_ip>
	User ec2-user
	IdentityFile ~/.ssh/<key_pair>.pem
	LocalForward 5432 airflow-postgres.xxx.xxx.rds.amazonaws.com:5432
```
- SSH into RDS from terminal
```ruby
ssh airflow-db
```
- verify if the tunnel is active from a new terminal. The output confirms the local port `5432` is forwarded to the private RDS through bastion.
```ruby
# local new terminal
lsof -i :5432
```
![lsof](images/03_rds_lsof.png)
- connect to RDS from terminal
```ruby

#  local new terminal: password can be found in secret manager or terraform output
psql -h localhost -p 5432 -U airflow airflow
```
![](images/04_rds_psql.png)

3. Create Redis (ElasticCache)
```ruby
terraform apply -target=aws_elasticache_cluster.redis --auto-approve
terraform apply -target=aws_vpc_security_group_egress_rule.redis_allow_all_traffic_ipv4 --auto-approve
```

4. Create ECS Cluster 
```ruby
terraform apply -target=aws_ecs_cluster.airflow --auto-approve
```
5. Create airflow init task definition
```ruby
terraform apply -target=aws_ecs_task_definition.airflow_init --auto-approve
terraform apply -target=aws_vpc_security_group_egress_rule.init_allow_all_traffic_ipv4  --auto-approve
terraform apply -target=aws_iam_role_policy_attachment.ecs_task_execution  --auto-approve
terraform apply -target=aws_iam_role_policy.access_secret_manager  --auto-approve
terraform apply -target=aws_iam_role_policy.access_s3  --auto-approve
```
6. Manually start the ECS task `airlow-init`
   - this task will run `airflow_init.sh` which init the DB and create airflow user
```ruby
# fill in private subnets and security group for the init task
aws ecs run-task \
  --cluster airflow-ecs \
  --task-definition airflow-init \
  --launch-type FARGATE \
  --network-configuration \
  "awsvpcConfiguration={
      subnets=[subnet-123,subnet-456,subnet-789],
      securityGroups=[sg-123456],
      assignPublicIp=DISABLED
  }"
  
# verify status
aws ecs describe-tasks \
--cluster airflow-ecs \
--tasks <task_arn>
```
- you can check cloudwatch logs for the task: go to `cloudwatch` -> log group `/ecs/airflow-init`. 
  Result should show:
```ruby
User "admin" created with role "Admin"
```
- Then, the aiflow-init task will stop and show `Essential container in task exited`

---
### Stage 4 - Set up the remaining blocks

- Set up all the remaining blocks (airflow & gitea ecs tasks, ALB, ACM, EFS, CloudMap)
```ruby
terraform apply --auto-approve
```

##### Stage 4a - Set up ECS tasks

- I choose AWS Fargate as the compute 
	- we just request the resources we need (CPU & Memory)
	- Use spot instance `capacity_provider = "FARGATE_SPOT"` to save money (for testing)
![](images/08_ecs.png)
##### Stage 4b - Set up EFS

- Flow
```ruby
EFS  (Mount Targets  +  EFS Access Point  +  /data mount)
  ↓
Gitea Task Volume (gitea-data)
  ↓
Gitea Container Mount (/data)
  ↓
Gitea (ECS) <- ALB
  ↓
gitdagbundle
  ↓
Airflow (ECS) <- ALB
```


![](images/07_efs.png)

##### Stage 4c - Set up CloudMap

![](images/06_cloudmap.png)

##### Stage 4d - Set up GitDagBundle

```ruby
# Flow
Git repo (Gitea)
  ↓
GitDagBundle
  ↓
Airflow Dag Processor
```

1. Update airflow config via ECS env vars.
```ruby
# terraform code for ECS env vars
    {
      name  = "AIRFLOW__DAG_PROCESSOR__DAG_BUNDLE_CONFIG_LIST"
      value = jsonencode([
        {
          name      = "dags-folder"
          classpath = "airflow.providers.git.bundles.git.GitDagBundle"
          kwargs = {
            tracking_ref = "main"
            repo_url = "http://gitea.airflow.local:3000/rachel/airflow_test.git"
            git_conn_id  = "gitea_git"
            refresh_interval = 30
          }
        }
      ])
    }
```
Make sure the **Gitea security group allows inbound 3000 from the Airflow security group**.

##### Stage 4e - Set up ALB

- approach
```ruby
Public ALB  
+ HTTPS listener (w/ ACM cert)
+ ALB security group ingress  (only allow my IP)
```

- Flow
```
ALB
├── :80  
│    └── Redirect -> 443  
│
└── :443
	 ├─ Host = airflow.rachel.com -> airflow-tg -> airflow-container
	 ├─ Host = gitea.rachel.com -> gitea-tg -> gitea-container
	 └─ Default -> fixed-response 404


https://airflow.rachel.com → ALB HTTPS listener → HTTP inside VPC -> Airflow ECS service  
https://gitea.rachel.com → same ALB HTTPS listener → HTTP inside VPC -> Gitea ECS service
```

1. Create a self-signed certificate, import to ACM and annotate the Ingress to use the ACM cert ARN.
   - create certificate
   - import the cert to ACM and copy the cert ARN value.
   - then add the cert to ALB listener:  `certificate_arn   = var.airflow_cert_arn`
```ruby

# private key
openssl genrsa -out airflow.key 2048
# use the private key to generate a self-signed cert
openssl req -new -x509 -key airflow.key -out airflow.crt -days 365 -subj "/CN=airflow.rachel.com"

# repeat for gitea
openssl genrsa -out gitea.key 2048
openssl req -new -x509 -key gitea.key -out gitea.crt -days 365 -subj "/CN=gitea.rachel.com"
```

![](images/09_alb.png)

2. When ALB is provisioned, get the IP of the ALB.
```ruby
nslookup airflow-alb-xxx.<region_name>.elb.amazonaws.com
```

3. Update the local `/etc/hosts` file to map ALB IP to the airflow & gitea hostname.
```ruby
sudo vi /etc/hosts

# @hosts file, add the IP
12.34.56.78 airflow.rachel.com
12.34.56.78 gitea.rachel.com
```

4. Go to chrome browser and enter airflow URL.
```ruby
https://airflow.rachel.com
```

![](images/10_airflow.png)

5. Go to chrome browser and enter gitea URL.
```ruby
https://gitea.rachel.com
```
![](images/11_gitea.png)

---
### Stage 5 - Test dbt + Snowflake pipeline on Airflow

1. Push example dag and dbt project to Gitea
2. Check if the dag shows up on Airflow UI
3. Create connection for Snowflake
4. Trigger the dag run
5. Check the task log
6. Check if data successfully loaded to Snowflake


---
## Additional: debug container via SSM

in progress

## Cleanup
```ruby
terraform destroy  --auto-approve
```

## Troubleshooting

in progress
## References

in progress