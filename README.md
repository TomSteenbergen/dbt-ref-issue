# dbt-ref-issue

Minimal example showcasing the issue when using `ref` with a duplicate model name. 

The `ref` macro points to the wrong project when your dbt project contains a model with
a name that already exists in an imported dbt project.

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

Compile the dbt models of `project_b`.
```bash
cd project_b
dbt compile
```

This will yield the following error:
```bash
RuntimeError: Found a cycle: model.project_b.model_x --> model.project_a.model_y
```

dbt incorrectly thinks that `project_a.model_y` is dependent on `project_b.model_x`
instead of `project_a.model_x`, resulting in a cyclic dependency. I would have expected
that dbt would, when using `ref` with a single argument in `project_a.model_y`,
reference the dbt model of _the same project_, i.e. `project_a.model_x`, regardless of 
whether we are running dbt from `project_a` or `project_b`. Instead, it seems to default
to the project from which you are running `dbt`.

## Tried workarounds

### Always use two arguments when using `ref`

You could always use the package name argument in `project_a`, even though it is
not importing any project (i.e. always use `ref("project_a", <model_name>)). This
would prevent the cyclic error in downstream dbt projects that contain a dbt model
with the same name. However, this workaround is not always desirable or even possible
in case the dbt project you are importing is not managed by your team/company.

### Override the `ref` macro

You could override the built-in `ref` macro to always default to the current model's 
package name if it is not explicitly supplied to `ref`:

```sql
{% macro ref() %}
    -- Extract user-provided positional and keyword arguments.
    {% set version = kwargs.get("version") or kwargs.get("v") %}
    {% set packagename = none %}
    {% if (varargs | length) == 1 -%} {% set modelname = varargs[0] %}
    {% else -%} {% set packagename = varargs[0] %} {% set modelname = varargs[1] %}
    {% endif %}

    {% if packagename is none %}
        {% do return(builtins.ref(model.package_name, modelname, version=version)) %}
    {% else %} 
        {% do return(builtins.ref(packagename, modelname, version=version)) %}
    {% endif %}

{% endmacro %}

```

Adding this macro in `project_b/macros/ref.sql` and running `dbt compile` again does
work in this minimal example. However, in our company's larger dbt project we run into
the following error:
