FROM apache/airflow:3.2.0-python3.11

USER root
RUN apt-get update && \
    apt-get install -y git

COPY ./config/* /
RUN chmod +x /airflow_init.sh
RUN chown -R airflow: ${AIRFLOW_HOME}

USER airflow

# dbt isolated venv
RUN python -m venv ${AIRFLOW_HOME}/dbt_venv && \
    source dbt_venv/bin/activate && \
    pip install --no-cache-dir dbt-snowflake && \
    deactivate

RUN pip install --no-cache-dir astronomer-cosmos
