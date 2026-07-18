from cosmos import DbtDag, ProjectConfig, ProfileConfig, ExecutionConfig
from cosmos.profiles import SnowflakeUserPasswordProfileMapping
from datetime import datetime
import os
from pathlib import Path

REPO_ROOT = Path(__file__).parents[2]
DBT_PROJECT_DIR = REPO_ROOT / "dbt" / "my_dbt_project"

profile_config = ProfileConfig(
    profile_name="my_dbt_project",
    target_name="dev",
    profile_mapping=SnowflakeUserPasswordProfileMapping(
        conn_id="snowflake_conn",
        profile_args={            
            "database": "taxi_data",
            "schema": "dbt",
            "threads": 20,
            },
    ),
)

my_cosmos_dag = DbtDag(
    dag_id="dbt_orders",

    # normal dag parameters
    schedule="@daily",
    start_date=datetime(2026, 5, 20),
    catchup=False,
    default_args={"retries": 2},

    # dbt settings
    project_config=ProjectConfig(
        # Cosmos checks: .../versions/<commit>/dbt/my_dbt_project/dbt_project.yml
        dbt_project_path=DBT_PROJECT_DIR,
    ),
    profile_config=profile_config,
    execution_config=ExecutionConfig(
        dbt_executable_path=f"{os.environ['AIRFLOW_HOME']}/dbt_venv/bin/dbt",
    ),

)