SELECT 'b'
FROM {{ ref("project_a", "model_y") }}