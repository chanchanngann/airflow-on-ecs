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