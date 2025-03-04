# dbt-ref-issue

Minimal example showcasing the issue when using `ref` with a duplicate model name in an
imported project.

## Problem

The `ref` macro points to the current dbt project in an upstream dbt project's model 
when referencing a model with a name that also exists in the current dbt project.

## Context

In our organization we have multiple dbt projects. The dbt projects of our central data
warehouse team is oftentimes imported as a package in downstream dbt projects. These
downstream dbt projects build their dbt models on top of their dbt models. 

Whenever the upstream dbt project uses `ref`, it uses the single-argument version as it
doesn't import any other dbt projects. In the downstream dbt projects, we do use the
two-argument version of `ref` to explicitly point to a dbt model from the upstream dbt
project. Still, the downstream dbt project runs into issues which is showcased by the
minimal example described below.

## Steps to reproduce

First spin up a test Postgres database:

```bash
docker compose up -d
```

Next, create your Poetry environment:

```bash
poetry install
poetry shell
```

Install the dbt dependencies required by `project_downstream`.
```bash
cd project_downstream
dbt deps
```

Run the dbt models of `project_downstream`.
```bash
dbt compile
```

This will yield the following error:
```bash
RuntimeError: Found a cycle: model.project_downstream.model_x --> model.project_upstream.model_y
```

dbt incorrectly thinks that `project_upstream.model_y` is dependent on 
`project_downstream.model_x` instead of `project_upstream.model_x`, resulting in a 
cyclic dependency since `project_downstream.model_x` references 
`project_upstream.model_y`. 

I would have expected that dbt, when using `ref` with a single argument in 
`project_upstream.model_y`, references the dbt model of _the same project_, i.e. 
`project_upstream.model_x`, regardless of whether we are running dbt from 
`project_upstream` or `project_downstream`. Instead, it seems to default to the project 
from which you are running `dbt`, even though `project_downstream` is not listed in 
`packages.yml` as a dependency of `project_upstream`.

## Tried workarounds

### Always use two arguments when using `ref`

You could always use the package name argument in `project_upstream`, even though it is
not importing any project (i.e. always use `ref("project_upstream", <model_name>)`). 
This would prevent the cyclic error in downstream dbt projects that contain a dbt model
with the same name. However, this workaround is not always desirable or even possible
in case the dbt project you are importing is not managed by your team/organization.

### Override the `ref` macro

You could override the built-in `ref` macro to always default to the current model's 
package name if it is not explicitly supplied to `ref`:

```sql
{% macro ref() %}
    -- Extract user-provided positional and keyword arguments.
    {% set version = kwargs.get("version") or kwargs.get("v") %}
    {% set packagename = none %}
    {% if (varargs | length) == 1 -%} 
        {% set modelname = varargs[0] %}
    {% else -%} 
        {% set packagename = varargs[0] %} 
        {% set modelname = varargs[1] %}
    {% endif %}

    {% if packagename is not none %}
        {% do return(builtins.ref(packagename, modelname, version=version)) %}
    -- If package name is not specified, assume the package from which we are calling `ref`.
    {% else %}
        {% do return(builtins.ref(model.package_name, modelname, version=version)) %}
    {% endif %}
{% endmacro %}

```

Adding this macro in `project_downstream/macros/ref.sql` and running `dbt compile` again 
does get rid of the cyclic dependency error. However, it does introduce a new issue:

```
Runtime Error
  Compilation Error in test unique_model_x_a (models/model_x/model_x.yml)
    dbt was unable to infer all dependencies for the model "unique_model_x_a".
    This typically happens when ref() is placed within a conditional block.
    
    To fix this, add the following hint to the top of the model "unique_model_x_a":
    
    -- depends_on: {{ ref('project_upstream', 'model_x') }}
    
    > in macro ref (macros/ref.sql)
    > called by test unique_model_x_a (models/model_x/model_x.yml)

```

This error is also thrown when using a different data test, e.g. `accepted_values`. The
suggested fix to add this `-- depends_on` comment is not desirable as these would need
to be added to the dbt models of the upstream project which can be owned by a different
team/organization. Another workaround I have found so far is removing the data test from 
`project_upstream.model_x`. For obvious reasons, this is also not a desirable 
workaround.
