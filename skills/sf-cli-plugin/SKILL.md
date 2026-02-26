---
name: sf-cli-plugin
description: Use this skill when the user asks to scaffold, develop, or test a Salesforce CLI plugin. This skill covers best practices for using @salesforce/sf-plugins-core, including command structure, message handling, flag definitions, and testing strategies.
---

# Salesforce CLI Plugin Development

This skill enables an AI agent to scaffold, develop, and test Salesforce CLI (sf) plugins using modern standards and `@salesforce/sf-plugins-core`.

## Core Principles

- **Modern Standards:** Use `@salesforce/sf-plugins-core` and TypeScript.
- **Consistency:** Follow Oclif patterns and Salesforce CLI naming conventions.
- **Messages:** Always use externalized messages in the `messages/` directory.
- **Validation:** Use strong typing for flags and results.

## Workflow

### 1. Scaffolding

To create a new plugin, use the generator:

```bash
npx @salesforce/plugin-generator@latest
```

Follow the interactive prompts to set the plugin name, description, and author.

### 2. Creating Commands

Commands should be placed in `src/commands/<topic>/<name>.ts`.

- **Inheritance:** Extend `SfCommand<T>` where `T` is the return type of the `run` method.
- **Imports:**
  ```typescript
  import { SfCommand, Flags } from "@salesforce/sf-plugins-core";
  import { Messages } from "@salesforce/core";
  ```

### 3. Implementing Logic

- **Messages:** Initialize messages using `Messages.importMessagesDirectory(__dirname)`.
- **Flags:** Define flags using `public static readonly flags`.
- **Run Method:** Implement the main logic in `public async run(): Promise<T>`.
- **Output:** Use `this.log()`, `this.styledHeader()`, `this.table()`, etc., for formatted output.

### 4. Internationalization (i18n)

Create a Markdown or JSON file in `messages/<command>.md`.
Reference messages in code using:

```typescript
const messages = Messages.loadMessages('plugin-name', 'command-file');
// ...
summary: messages.getMessage('summary'),
```

### 5. Testing

- Use `@oclif/test` and `chai`.
- Mock Salesforce interactions using `@salesforce/core/lib/testSetup`.
- Run tests with `npm test`.

### 6. Development Loop

- **Build:** `npm run build`
- **Link for testing:** `sf plugins link`
- **Execute locally:** `./bin/dev <command>`

## Best Practices

- **Flag Descriptions:** Every flag must have a `summary` and optionally a `description`.
- **Error Handling:** Use `SfError` for user-facing errors.
- **JSON Output:** Ensure the `run` method returns a data structure that makes sense when the `--json` flag is used.
- **Environment:** Respect `SF_LOG_LEVEL` and other standard environment variables.
