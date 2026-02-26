# Agent Script Variables

## 1. Variable Reference

| Variable Name | Detail |
|---|---|
| Regular | User-defined global state. |
| Linked | Tied to external sources (e.g., `@session.sessionID`). |
| System | Predefined (e.g., `@system_variables.user_input`). |

### 1.1 Regular Variables
- `var_name: [mutable] <type> [= <default_value>]`
- `description: "Strongly recommended"` — helps LLM use variable correctly.
- `label: "Friendly Name"` — Optional UI label.

**Supported Types:**
- `string`: Alphanumeric text.
- `number`: Floating point (IEEE 754).
- `integer`: Whole numbers.
- `long`: Large integers.
- `boolean`: `True` or `False`.
- `date`: `YYYY-MM-DD`.
- `datetime`: ISO-8601 timestamps.
- `time`: Time values.
- `currency`: Currency values.
- `id`: Salesforce 15/18 character IDs.
- `object`: JSON objects `{"key": "value"}`.
- `list[<type>]`: List of a specific type (e.g., `list[string]`).

### 1.2 Linked Variables
- `var_name: linked <type>`
- `source: @session.variable`
- **Restrictions**: No default values; cannot be set by agent; cannot be `object` or `list`.

### 1.3 System Variables
- `@system_variables.user_input`: The customer's most recent utterance. Read-only.

## 2. Variable Access Patterns

```yaml
# Logic block
if @variables.verified == True:
  set @variables.data = @outputs.result

# Prompt block
| Hello {!@variables.member_name}.

# Set from action output
set @variables.data = @outputs.result

# Set directly
set @variables.counter = @variables.counter + 1
```
