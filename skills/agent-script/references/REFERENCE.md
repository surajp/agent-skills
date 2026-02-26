# Agent Script Language Reference

## 1. Syntax Fundamentals

| Rule | Detail |
|---|---|
| Structure | `key: value` pairs; top-level keys are blocks |
| Indentation | 2 spaces or 1 tab — consistent throughout |
| Logic prefix | `->` — runs deterministically before the LLM prompt |
| Prompt prefix | `|` — natural language appended to the LLM prompt |
| Multiline strings | `|` after the key (YAML block scalar) |
| Comments | `# comment` — ignored by compiler |

### Resource Access Syntax

```yaml
@actions.name        Reference a topic-level action definition
@topic.name          Reference another topic
@variables.name      Reference a global variable
@system_variables    Reference a system variable (e.g. @system_variables.user_input)
@outputs.name        Reference an action output (current block only)
@utils.function      Reference a built-in utility
```

In **prompt text** (inside `|` lines), embed values with:
`{!@variables.name}`, `{!@actions.name}`, `{!@topics.name}`

## 2. Supported Operators

| Category | Operators |
|---|---|
| Comparison | `==` `!=` `>` `<` `>=` `<=` |
| Logical | `and` `or` `not` |
| Arithmetic | `+` `-` (no `*` or `/`) |
| Null checks | `is None` `is not None` |

## 3. Block Reference

### Complete File Structure
```yaml
system:              Global persona + required messages
config:              Agent metadata
variables:           Global state
language:            Locale config
connection:          External connections (optional)
before_reasoning:    Logic to run before any topic logic (optional)
after_reasoning:     Logic to run after any topic logic (optional)
start_agent <name>:  Entry-point topic — runs on every utterance
topic <name>:        One or more domain-specific topics
```

### 3.1 `system` Block
- `instructions`: Global persona.
- `messages.welcome`: Required welcome message.
- `messages.error`: Required error message.

### 3.2 `config` Block
- `developer_name`: Unique snake_case API name.
- `agent_label`: Display name.
- `default_agent_user`: Running user for actions.

### 3.3 `language` Block
- `default_locale`: Default (e.g., `en_US`).
- `additional_locales`: Comma-separated locales.
- `all_additional_locales`: Boolean.

### 3.4 `connection` Block (Messaging)
- `escalation_message`: Message before human handoff.
- `outbound_route_type`: Handoff mechanism (e.g., `OmniChannelFlow`).
- `outbound_route_name`: API name of the route.
- `adaptive_response_allowed`: Boolean.

### 3.5 `before_reasoning` and `after_reasoning` Blocks
- **Logic Only**: These blocks contain deterministic logic (`->`). They **cannot** contain prompt instructions (`|`).
- **Use Cases**: Setting variables based on state, transitioning to topics before/after processing.
- **Top-level vs. Topic-level**:
  - **Top-level**: Runs before/after any topic-specific logic.
  - **Topic-level**: Inside a `topic` block, runs before/after the topic's reasoning loop.
- **Transition Syntax**: Use `transition to @topic.name` (omit `@utils.`).

## 4. Topic & Start Agent Properties

| Property | Required | Description |
|---|---|---|
| `description` | Yes | High-quality intent description for routing. |
| `system.instructions` | No | Topic-level override for persona/tone. |
| `before_reasoning` | No | Logic before reasoning loop. |
| `reasoning.instructions` | Yes | Mixed logic and prompts for the LLM. |
| `reasoning.actions` | No | Tools available for LLM choice. |
| `after_reasoning` | No | Logic after reasoning loop exits. |
| `actions` | No | Schema definitions for topic-specific actions. |
