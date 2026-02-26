# Agent Script Best Practices & Patterns

## 1. Slot Filling Pattern

Use `@utils.setVariables` with the `...` placeholder to extract user-provided information from the conversation.

```yaml
reasoning:
  actions:
    capture_details: @utils.setVariables
      with phone = ...
      with reason = ...
      description: "Extract phone number and reason"
```

### Slot Filling Rules
- Can be used for top-level action inputs (called by LLM).
- **Cannot** be used for chained action inputs (run deterministically).

## 2. Deterministic Routing

Always perform state-based checks (e.g., authentication) at the top of the `start_agent` block.

```yaml
start_agent topic_selector:
  reasoning:
    instructions: ->
      # 1. Enforce required flow
      if @variables.verified == False:
        transition to @topic.Identity
      
      # 2. Proceed if verified
      | Analyze user intent to select the correct topic.
```

## 3. Action Chaining

Deterministically run a sequence of actions in response to a single LLM tool call.

```yaml
reasoning:
  actions:
    check_refund: @actions.verify_eligibility
      run @actions.process_refund
      with order_id = @outputs.order_id
```

## 4. Instruction Overrides

Use topic-level overrides to change persona or focus for specific domains.

```yaml
topic VIP_Concierge:
  system:
    instructions: "You are a formal, high-end concierge for our top-tier members."
```

## 5. Variable Usage Strategy

- **Reuse**: Store values for use in other topics.
- **State Tracking**: Keep track of user verification and progress.
- **Available When**: Use variables to gate sensitive tools.
- **Descriptions**: Always provide a `description` for each variable to help the LLM understand its purpose.
- **Initialization**: Sensible defaults like `""` (string), `False` (boolean), or `0` (number).
- **Mutable**: Explicitly use `mutable` if the agent needs to change the value.
- **Labels**: Use `label` for friendly UI display.
