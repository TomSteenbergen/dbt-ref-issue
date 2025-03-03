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