# Agent Script Actions & Tools

## 1. Action Schema Definitions

Actions are defined at the topic level and describe the capabilities of the agent.

```yaml
actions:
  action_name:
    description: "What it does"
    label: "Friendly Name"
    include_in_progress_indicator: True
    require_user_confirmation: False
    inputs:
      param: string
        is_required: True
        description: "Input help"
    outputs:
      result: string
        filter_from_agent: False # If True, LLM can't see this value
        complex_data_type_name: "lightning__recordInfoType"
    target: "flow://FlowName"
```

### Supported Targets
- `flow://FlowAPIName`
- `apex://ApexClassName`
- `promptTemplate://TemplateName`

## 2. Reasoning Actions (Tools)

Tools are the actions made available to the LLM for choice-based execution.

```yaml
reasoning:
  actions:
    # 1. Action as a tool
    tool_name: @actions.defined_action
      with param = ... # Slot filling
      set @variables.target = @outputs.source

    # 2. Action Chaining
    get_data: @actions.fetch
      run @actions.process
      with data = @outputs.result

    # 3. Slot Filling Utility
    get_user_info: @utils.setVariables
      with first_name = ...
      description: "Extract name"

    # 4. Topic Delegation (Return allowed)
    consult_expert: @topic.Expert_Topic

    # 5. Transition (No return)
    exit_to_support: @utils.transition to @topic.Support

    # 6. Escalation
    talk_to_human: @utils.escalate
```

## 3. Tool Gating (`available when`)

You can control when a tool is visible to the LLM using the `available when` clause.

```yaml
actions:
  refund_order: @actions.process_refund
    available when @variables.order_id is not None and @variables.eligible == True
```
