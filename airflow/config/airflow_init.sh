#!/usr/bin/env bash

set -Eeuo pipefail

until airflow db check; do
  echo "Waiting for database..."
  sleep 5
done

airflow db migrate

# create admin only if not exists
airflow users list | grep -q '^admin' || airflow users create \
  --username admin \
  --firstname Rachel \
  --lastname xxx \
  --role Admin \
  --email admin@example.com \
  --password "${AIRFLOW_ADMIN_PASSWORD}"

# add aws connection if not exists (for s3 remote logging)
airflow connections get aws_default || airflow connections add aws_default --conn-type aws
