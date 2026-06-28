# Airflow on AWS ECS Fargate

This project deploys Apache Airflow on AWS ECS Fargate using the Celery Executor and Terraform. The objective is to evaluate a scalable Airflow architecture that supports distributed task execution, Git-based DAG deployment while maintaining a fully containerized and serverless infrastructure.

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
**Stage 1**
1. Set up networking (vpc, subnets) and bastion host
2. Build custom image in bastion host
3. Push the image to ECR
   
**Stage 2**
4. Create RDS (airflow metadata DB)
5. Create Redis (Celery broker)
6. Create ECS cluster
7. Create & Run airflow-init ECS task (one-off task)
   
**Stage 3**
8. Create ALB, target groups & listener rules
9. Create EFS for Gitea container (mount volume for dags)
10. Create ECS Service for Gitea & IAM Roles
11. Create ECS Services for Airflow & IAM Roles
	- 5 long-running ECS services
		airflow-api-server  
		airflow-scheduler  
		airflow-worker  
		airflow-triggerer  
		airflow-dag-processor
		
**Stage 4**
12. Create certificate and upload to ASM
13. Add DNS to local hosts file
    
**Stage 5**
14. Test push dag to Gitea
15. Test dbt pipeline in airflow to snowflake
---
### Stage 1 - Push the images to ECR
1. Set up vpc, s3 gateway endpoint and bastion host.
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
2. SSH into bastion host and create folder `airflow`
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

---
### Stage 2 - Run airflow-init task
1. Create RDS
```ruby
terraform apply -target=aws_db_instance.airflow_db
terraform apply -target=aws_vpc_security_group_ingress_rule.rds_allow_airflow_init_sg  --auto-approve
```
2. Test connection to RDS
- register ssh config in `~/.ssh/config`
```
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
```
ssh airflow-db
```
- verify if the tunnel is active from new termina. The output confirms the local port `5432` is forwarded to the private RDS through bastion.
`diagram!!!!!!!!!!!!!!!!!`
- connect to RDS from terminal
```ruby
# password can be found in secret manager or terraform output
psql -h localhost -p 5432 -U airflow airflow
```

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
   - this task will do run `airflow_init.sh` which init the DB and create airflow users
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
Then, the aiflow-init task will stop and show `Essential container in task exited`

---
### Stage 3 - Set up Airflow and Gitea
```ruby
ALB
├── :80  
│    └── Redirect -> 443  
│
└── :443
	 ├─ Host = airflow.rachel.com -> airflow-tg -> airflow-container
	 ├─ Host = gitea.rachel.com -> gitea-tg -> gitea-container
	 └─ Default -> fixed-response 404
```

1. Set up all the remaining blocks
```ruby
terraform apply
```

---
### Stage 4 - DNS routing

1. Get the public IP of ALB
```ruby
nslookup airflow-alb-123456789.xxx.elb.amazonaws.com
```
2. Update the local `/etc/hosts` file to map the ALB Controller’s external IP to the airflow base url.
```ruby
sudo vi /etc/hosts

# @hosts file, add the IP
12.345.67.88 rachel.airflow.com
12.345.67.89 rachel.airflow.com

12.345.67.88 rachel.gitea.com
12.345.67.89 rachel.gitea.com
```
**TODO**: Create certificate and upload to ACM
3. Go to browser
```ruby
https://rachel.airflow.com
```
[diagram]
```ruby
https://rachel.gitea.com
```
[diagram]

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
terraform destroy
```

## Troubleshooting

in progress
## References

in progress