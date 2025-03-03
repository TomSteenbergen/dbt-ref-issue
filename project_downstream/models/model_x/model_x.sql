SELECT 'b' AS col_b
FROM {{ ref("project_upstream", "model_y") }}