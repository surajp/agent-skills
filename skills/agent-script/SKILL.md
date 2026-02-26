---
name: salesforce-agent-script
description: Authoritative reference for generating and working with Salesforce Agentforce Agent Script. Use when building,modifying,explaining or doing anything involving Salesforce Agent Script.
---

# Salesforce Agent Script

This skill provides the authoritative context for an AI agent generating Agent Script code. Use this when creating or updating Agentforce agents using the property-based, whitespace-sensitive Agent Script language.

## Quick Start: Basic Structure

```yaml
system:
   instructions: "You are a friendly assistant."
   messages:
      welcome: "Hi! How can I help?"
      error: "Something went wrong."

config:
   developer_name: "My_Agent"
   agent_label: "My Agent"

language:
   default_locale: en_US

variables:
   user_name: mutable string
   verified: mutable boolean = False

topic Order_Management:
   description: "Handles orders"
   before_reasoning: ->
      if @variables.verified == False: transition to @topic.Identity
   reasoning:
      instructions: |
         Greet the user and check their order status.
   after_reasoning: ->
      if @variables.order_status == "delivered": set @variables.completed = True

start_agent topic_selector:
   description: "Route user intent"
   reasoning:
      instructions: ->
         if @variables.verified == False: transition to @topic.Identity
         | Select a tool based on user intent.
      actions:
         go_to_order: @utils.transition to @topic.Orders
            available when @variables.verified == True
```

## Core Instructions

### 1. Language Fundamentals

- **Logic vs. Prompt**: Use `->` for deterministic logic (runs before LLM) and `|` for natural language prompts.
- **Indentation**: Use 3 spaces or 1 tab consistently. Mixing causes parse errors.
- **Case Sensitivity**: All keys and resource names are case-sensitive.
- **Resource Access**: Use `@variables.name`, `@actions.name`, `@topic.name`, and `@system_variables.user_input`.

### 2. Reasoning Instructions (`reasoning.instructions`)

- **Deterministic First**: Always place `if` checks and `run` commands at the top of the block.
- **Action Execution**: Use `run @actions.name` with `with` for inputs and `set` for outputs.
- **Variable Sets**: Use `set @variables.name = value` for both literals and expressions.
- **Transitions**: Use `transition to @topic.name` inside logic blocks for immediate, one-way jumps.

### 3. Slot Filling & Tools (`reasoning.actions`)

- **Extraction**: Use `@utils.setVariables` with `...` placeholders to let the LLM extract values from conversation.
- **Guarding Tools**: Use `available when <condition>` to show/hide tools from the LLM based on state.
- **Chaining**: Use `run @actions.next` inside a tool definition to execute a sequence of actions from one tool call.

## Reference Material

For detailed syntax, variable types, and advanced patterns, see the following references:

- **Language & Syntax**: [REFERENCE.md](references/REFERENCE.md) (Operators, syntax rules, and block structure)
- **Variables & State**: [VARIABLES.md](references/VARIABLES.md) (Types, linked variables, and system variables)
- **Actions & Tools**: [ACTIONS.md](references/ACTIONS.md) (Schema definitions, targets, and tool patterns)
- **Best Practices**: [PATTERNS.md](references/PATTERNS.md) (Slot filling, deterministic routing, and chaining)

## Example Agent Scripts

Complete, working examples demonstrating key patterns and features:

### Getting Started

- **[HelloWorld.agent](references/examples/HelloWorld.agent)** - Minimal agent demonstrating basic structure with system instructions, welcome messages, and simple topic routing
- **[VariableManagement.agent](references/examples/VariableManagement.agent)** - State management using mutable variables (string, number, boolean, list) to track conversation state across turns

### Working with Actions

- **[ActionDefinitions.agent](references/examples/ActionDefinitions.agent)** - Comprehensive guide to defining and using actions with inputs, outputs, and targets (Flow/Apex)
- **[ExternalAPIIntegration.agent](references/examples/ExternalAPIIntegration.agent)** - Integrating with external systems via Flows and Apex for weather, payments, and shipping APIs

### Advanced Patterns

- **[MultiStepWorkflows.agent](references/examples/MultiStepWorkflows.agent)** - Multi-step onboarding workflow with sequential action execution, state tracking, and conditional progression
- **[ErrorHandling.agent](references/examples/ErrorHandling.agent)** - Comprehensive validation and error handling patterns for financial transfers with safety checks and user feedback

## Implementation Guidance

1. **Start Agent**: Always include a `start_agent` block to handle classification and routing.
2. **Descriptions**: Write detailed, distinct `description` strings for topics and actions; these are the primary drivers for LLM routing accuracy.
3. **Required Flows**: Use `if` checks at the start of `start_agent` to enforce authentication or data-gathering flows before allowing general intent processing.
4. **Instruction Overrides**: Use topic-level `system.instructions` to change persona or resolve conflicts with global instructions for specific domains.
5. **Language Block**: A `language` block is required. The `default_locale` value MUST be quoted (e.g., `default_locale: "en_US"`).
6. **Project Structure**: Agent scripts MUST be stored in the following directory structure:
   `<default-project-folder>/main/default/aiAuthoringBundles/<scriptApiName>/`
   - Agent Script: `<scriptApiName>.agent`
   - Metadata File: `<scriptApiName>.bundle-meta.xml` (See [bundle-meta.xml](./bundle-meta.xml))
7. **Validation**: Use the following SF CLI command to validate your agent authoring bundle:
   `sf agent:validate:authoring-bundle --api-name <scriptApiName>`
8. **Required Config**: For `EinsteinServiceAgent` types, `default_agent_user` is required in the `config` block (e.g., `default_agent_user: "EinsteinServiceAgentUser"`).
9. **Reliable Routing**: While `transition to` is supported in logic blocks, using `available when` on tools in the `start_agent` block is the most robust way to enforce state-based routing (like authentication) and avoid compiler syntax errors.
