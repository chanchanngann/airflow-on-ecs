{{ config(materialized='table') }}
SELECT
    customer,
    SUM(amount) AS total_revenue
FROM {{ ref('stg_orders2') }}
GROUP BY customer