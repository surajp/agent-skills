---
name: apex-development
description: Use this skill when doing any Apex development work in Salesforce, including writing new classes, updating existing code, and implementing triggers. This skill covers design patterns, best practices, testing strategies, and governor limit management to ensure high-quality, maintainable Apex code.
---

# Apex Development Skill

This skill provides comprehensive guidance for developing Apex code in Salesforce, including design patterns, best practices, testing strategies, and governor limit management.

## Table of Contents

1. [Overview](#overview)
2. [Design Patterns](#design-patterns)
3. [Naming Conventions](#naming-conventions)
4. [Code Style](#code-style)
5. [Governor Limits & Bulkification](#governor-limits--bulkification)
6. [Testing Patterns](#testing-patterns)
7. [Error Handling](#error-handling)
8. [Security Best Practices](#security-best-practices)
9. [Logging](#logging)
10. [Async Processing](#async-processing)

---

## Overview

Apex is a strongly-typed, object-oriented programming language that runs on the Salesforce Platform. When writing Apex code, always consider:

- **Governor Limits**: Design for bulk operations (200+ records)
- **Sharing Rules**: Always declare sharing explicitly
- **Test Coverage**: Maintain 90%+ code coverage
- **Performance**: Optimize SOQL queries and DML operations
- **Maintainability**: Follow established design patterns

---

## Some important points to remember

- Each class is accompanied by a meta.xml file.
- Classes should be deployed using 'sf project deploy start' command after any changes are made before running tests.

## Design Patterns

### 1. Selector Pattern

**Purpose**: Centralize all SOQL queries for a given object or domain.

**Characteristics**:

- Singleton pattern via `getInstance()`
- Static instance variable marked `@TestVisible`
- Returns `Database.QueryLocator` for batch processing
- Returns `List<SObject>` for synchronous queries
- All queries use explicit fields (avoid `SELECT *`)

**Example**:

```apex
public with sharing class AccountSelector {
  @TestVisible
  private static AccountSelector instance = null;

  public static AccountSelector getInstance() {
    if (instance == null) {
      instance = new AccountSelector();
    }
    return instance;
  }

  public List<Account> selectById(Set<Id> accountIds) {
    return [
      SELECT Id, Name, Industry, AnnualRevenue
      FROM Account
      WHERE Id IN :accountIds
      WITH USER_MODE
    ];
  }

  public Database.QueryLocator selectActiveAccounts() {
    String query = 'SELECT Id, Name FROM Account WHERE IsActive__c = true';
    return Database.getQueryLocator(query);
  }
}
```

**Benefits**:

- Reusable queries across services and handlers
- Easy to mock in tests
- Consistent security enforcement
- Single responsibility principle

---

### 2. Service Pattern

**Purpose**: Encapsulate business logic and orchestrate operations.

**Characteristics**:

- Singleton pattern via `getInstance()`
- Coordinates between selectors, handlers, and other services
- No direct SOQL (delegate to Selectors)
- Returns operation results for error handling
- Well-documented with JavaDoc

**Example**:

```apex
public with sharing class AccountService {
  @TestVisible
  private static AccountService instance = null;

  public static AccountService getInstance() {
    if (instance == null) {
      instance = new AccountService();
    }
    return instance;
  }

  /**
   * Updates account industries based on revenue thresholds
   * @param accountIds Set of account IDs to process
   * @return List of SaveResults for error handling
   */
  public List<Database.SaveResult> updateAccountIndustries(Set<Id> accountIds) {
    List<Account> accounts = AccountSelector.getInstance().selectById(accountIds);
    List<Account> accountsToUpdate = new List<Account>();

    for (Account acc : accounts) {
      if (acc.AnnualRevenue > 10000000) {
        acc.Industry = 'Enterprise';
        accountsToUpdate.add(acc);
      }
    }

    if (!accountsToUpdate.isEmpty()) {
      return Database.update(accountsToUpdate, false);
    }
    return new List<Database.SaveResult>();
  }
}
```

---

### 3. Handler Pattern

**Purpose**: Handle specific operations or delegate trigger logic.

**Characteristics**:

- Single responsibility
- Dependency injection via constructor
- Returns modified records (caller performs DML)
- Can be stateless or stateful

**Example**:

```apex
public with sharing class AccountIndustryHandler {
  private final AccountValidationService validationService;

  public AccountIndustryHandler() {
    this.validationService = AccountValidationService.getInstance();
  }

  @TestVisible
  public AccountIndustryHandler(AccountValidationService svc) {
    this.validationService = svc;
  }

  public List<Account> populateIndustry(List<Account> accounts) {
    List<Account> modifiedAccounts = new List<Account>();

    for (Account acc : accounts) {
      if (validationService.needsIndustryUpdate(acc)) {
        acc.Industry = validationService.deriveIndustry(acc);
        modifiedAccounts.add(acc);
      }
    }

    return modifiedAccounts;
  }
}
```

---

### 4. Trigger Handler Pattern

**Purpose**: Manage trigger execution with consistent patterns and bypass mechanisms.

**Example Base Class**:

```apex
public virtual class TriggerHandler {
  protected Boolean isTriggerExecuting;

  private static Set<String> bypassedHandlers = new Set<String>();

  public static void bypass(String handlerName) {
    bypassedHandlers.add(handlerName);
  }

  public static void clearBypass(String handlerName) {
    bypassedHandlers.remove(handlerName);
  }

  public void run() {
    if (bypassedHandlers.contains(this.getHandlerName())) {
      return;
    }

    if (Trigger.isBefore) {
      if (Trigger.isInsert)
        this.beforeInsert();
      else if (Trigger.isUpdate)
        this.beforeUpdate();
      else if (Trigger.isDelete)
        this.beforeDelete();
    } else if (Trigger.isAfter) {
      if (Trigger.isInsert)
        this.afterInsert();
      else if (Trigger.isUpdate)
        this.afterUpdate();
      else if (Trigger.isDelete)
        this.afterDelete();
      else if (Trigger.isUndelete)
        this.afterUndelete();
    }
  }

  protected virtual void beforeInsert() {
  }
  protected virtual void beforeUpdate() {
  }
  protected virtual void beforeDelete() {
  }
  protected virtual void afterInsert() {
  }
  protected virtual void afterUpdate() {
  }
  protected virtual void afterDelete() {
  }
  protected virtual void afterUndelete() {
  }

  protected virtual String getHandlerName() {
    return String.valueOf(this).substring(0, String.valueOf(this).indexOf(':'));
  }
}
```

**Example Implementation**:

```apex
public class AccountTriggerHandler extends TriggerHandler {
  @TestVisible
  protected override void beforeInsert() {
    AccountIndustryHandler handler = new AccountIndustryHandler();
    handler.populateIndustry((List<Account>) Trigger.new);
  }

  @TestVisible
  protected override void afterUpdate() {
    // Delegate to specific handlers
    Map<Id, Account> oldMap = (Map<Id, Account>) Trigger.oldMap;
    List<Account> newList = (List<Account>) Trigger.new;

    // Process only records where Industry changed
    List<Account> industryChanged = new List<Account>();
    for (Account acc : newList) {
      if (acc.Industry != oldMap.get(acc.Id).Industry) {
        industryChanged.add(acc);
      }
    }

    if (!industryChanged.isEmpty()) {
      new AccountIndustryNotification(industryChanged).sendNotifications();
    }
  }
}
```

**Trigger Implementation**:

```apex
trigger AccountTrigger on Account(before insert, before update, after insert, after update) {
  new AccountTriggerHandler().run();
}
```


***Queueable Jobs***

- Use Apex Cursors for fetching large datasets in batches
- Always attach a Finalizer class for error handling and retry logic. Typically, the Queueable class will also implement the Finalizer interface, and in execute(QueueableContext) method, you attach the finalizer using System.attachFinalizer(this); 
- Before attaching finalizer check the QueueableContext argument is not null to ensure that the job is indeed a Queueable job. Else the attachFinalizer method will throw an exception.
- For re-enqueueing the same job use System.enqueueJob(this);
- All non-transient, properties of the Queueable class are serialized and deserialized across transactions, so you can maintain state by using instance variables. Just be mindful of the total heap size and governor limits when doing so.

---

## Naming Conventions

### Classes

- **PascalCase** for all class names
- **Suffix Patterns**:
  - `*Selector` - SOQL query classes
  - `*Service` - Business logic services
  - `*Handler` - Trigger handlers or operation handlers
  - `*Queueable` - Queueable implementations
  - `*Batch` - Batch Apex classes
  - `*Scheduler` - Schedulable classes
  - `*Action` - Invocable/Flow actions
  - `*Controller` - LWC/Aura controllers
  - `*Test` - Test classes
  - `*Exception` - Custom exceptions
  - `Abstract*` - Abstract base classes
  - `I*` - Interfaces (e.g., `IAccountProcessor`)

### Methods and Variables

- **camelCase** for methods and variables
- **Boolean methods**: Use `is*`, `has*`, `should*`, `can*` prefixes
- **Getter methods**: Avoid `get*` prefix for simple property access
- ***Verb-Noun** for action methods (e.g., `updateAccountIndustries`, `sendEmailNotification`)
- ***Noun-Verb** for query methods (e.g., `accountsToUpdate`, `industryChangedAccounts`)
- ***Descriptive names** that clearly indicate purpose and return type
- ***Avoid abbreviations** unless widely understood (e.g., `Id`, `URL`, `API`)
- ***Avoid shadowing*** Avoid Apex standard class and SObject names for variables and methods (e.g., `Test`,`Account`, `Contact`, `update`, `delete`)

**Examples**:

```apex
private void processRecords() { }
public Boolean isValidEmail(String email) { }
private Integer recordCount = 0;
private Boolean hasErrors = false;
```

### Constants

- **UPPER_SNAKE_CASE** for constants
- Group related constants in dedicated classes

**Example**:

```apex
public class AccountConstants {
  public static final Integer MAX_ACCOUNTS_PER_BATCH = 200;
  public static final String DEFAULT_INDUSTRY = 'Technology';
  public static final Decimal ENTERPRISE_REVENUE_THRESHOLD = 10000000;
}
```

---

## Code Style

### Sharing Declarations

**Always explicitly declare sharing**:

```apex
public with sharing class AccountService { }        // Enforce sharing (default)
public without sharing class SystemService { }      // Bypass sharing (rare, needs justification)
public inherited sharing class FlexibleService { }  // Inherit from caller
```

### Null Safety

Use **safe navigation** (`?.`) and **null coalescing** (`??`) operators:

```apex
String industry = account?.Industry ?? 'Unknown';
Integer size = accounts?.size() ?? 0;
Decimal revenue = account?.Parent?.AnnualRevenue ?? 0;
```

### Modern Syntax

**Switch Statements**:

```apex
switch on triggerOperation {
    when BEFORE_INSERT {
        this.beforeInsert();
    }
    when AFTER_UPDATE {
        this.afterUpdate();
    }
    when else {
        // Handle unexpected
    }
}
```

*** If else Statements**:

- Ensure if else statements are always enclosed in curly braces, even if they contain only one statement. This improves readability and reduces the risk of bugs when adding additional statements later.

```apex
if (accountsToUpdate.isEmpty()) {
    return new List<Database.SaveResult>();
} else {
    return Database.update(accountsToUpdate, false);
}
```

**String Formatting**:

```apex
String message = String.format('Account {0} has revenue ${1}',
    new List<String>{account.Name, String.valueOf(account.AnnualRevenue)});
```

---

## Governor Limits & Bulkification

### SOQL Queries (Limit: 100 per transaction)

**Always design for bulk operations**:

```apex
// ✅ GOOD - Bulkified
Set<Id> accountIds = new Set<Id>();
for (Contact con : contacts) {
    accountIds.add(con.AccountId);
}
Map<Id, Account> accountMap = new Map<Id, Account>(
    [SELECT Id, Name FROM Account WHERE Id IN :accountIds]
);

// ❌ BAD - SOQL in loop
for (Contact con : contacts) {
    Account acc = [SELECT Id, Name FROM Account WHERE Id = :con.AccountId];
}
```

### DML Operations (Limit: 150 per transaction)

**Batch DML operations**:

```apex
// ✅ GOOD - Single DML
List<Account> accountsToUpdate = new List<Account>();
for (Account acc : accounts) {
    if (acc.AnnualRevenue > 1000000) {
        acc.Rating = 'Hot';
        accountsToUpdate.add(acc);
    }
}
if (!accountsToUpdate.isEmpty()) {
    update accountsToUpdate;
}

// ❌ BAD - DML in loop
for (Account acc : accounts) {
    acc.Rating = 'Hot';
    update acc;  // Governor limit violation!
}
```

### CPU Time (Limit: 10,000ms synchronous, 60,000ms async)

**Use efficient data structures**:

```apex
// ✅ GOOD - O(1) lookup using Map
Map<Id, Account> accountMap = new Map<Id, Account>(accounts);
for (Contact con : contacts) {
    Account acc = accountMap.get(con.AccountId);  // Fast
}

// ❌ BAD - O(n²) nested loops
for (Contact con : contacts) {
    for (Account acc : accounts) {
        if (acc.Id == con.AccountId) {  // Slow
            // Process
        }
    }
}
```

### Heap Size (Limit: 6MB synchronous, 12MB async)

**Avoid loading unnecessary data**:

```apex
// ✅ GOOD - Query only needed fields
List<Account> accounts = [SELECT Id, Name FROM Account LIMIT 10000];

// ❌ BAD - Querying all fields
List<Account> accounts = [SELECT FIELDS(ALL) FROM Account LIMIT 10000];
```

### Best Practices

1. **Use Database methods with partial success**:

   ```apex
   List<Database.SaveResult> results = Database.update(accounts, false);
   for (Database.SaveResult result : results) {
       if (!result.isSuccess()) {
           // Handle error without blocking other records
       }
   }
   ```

2. **Use Set/Map for lookups** instead of nested loops

3. **Query related records in single query** using relationships:

   ```apex
   List<Account> accounts = [
       SELECT Id, Name, (SELECT Id, FirstName FROM Contacts)
       FROM Account
       WHERE Id IN :accountIds
   ];
   ```

4. **Consider async processing** for large datasets (Queueable/Batch)

---

## Testing Patterns

### Test Class Structure

```apex
@IsTest
private class AccountServiceTest {
  @TestSetup
  static void setupTestData() {
    // Create reusable test data
    List<Account> accounts = new List<Account>();
    for (Integer i = 0; i < 200; i++) {
      accounts.add(new Account(Name = 'Test Account ' + i, Industry = 'Technology'));
    }
    insert accounts;
  }

  @IsTest
  private static void shouldUpdateAccountIndustries() {
    // Arrange
    List<Account> accounts = [SELECT Id FROM Account];
    Set<Id> accountIds = new Set<Id>();
    for (Account acc : accounts) {
      accountIds.add(acc.Id);
    }

    // Act
    Test.startTest();
    List<Database.SaveResult> results = AccountService.getInstance().updateAccountIndustries(accountIds);
    Test.stopTest();

    // Assert
    Assert.isNotNull(results, 'Results should not be null');
    for (Database.SaveResult result : results) {
      Assert.isTrue(result.isSuccess(), 'All updates should succeed: ' + result.getErrors());
    }
  }

  @IsTest
  private static void shouldHandleEmptyAccountSet() {
    // Act
    Test.startTest();
    List<Database.SaveResult> results = AccountService.getInstance().updateAccountIndustries(new Set<Id>());
    Test.stopTest();

    // Assert
    Assert.areEqual(0, results.size(), 'Should return empty list for empty input');
  }
}
```

### Test Data Best Practices

1. **Use @TestSetup** for shared data:

   ```apex
   @TestSetup
   static void setup() {
       // Runs once before all test methods
   }
   ```

2. **Create bulk test data** (200+ records) to test governor limits

3. **Use Test.startTest() and Test.stopTest()** to reset governor limits

4. **Test positive, negative, and edge cases**

### Assertions

**Use modern Assert class**:

```apex
// Modern approach
Assert.areEqual(expected, actual, 'Message');
Assert.isTrue(condition, 'Message');
Assert.isNotNull(value, 'Message');
Assert.isFalse(condition, 'Message');
Assert.fail('Explicit failure message');

// Legacy approach (avoid)
System.assertEquals(expected, actual);
System.assert(condition);
```

### Mocking Dependencies

When using a mocking framework, inject mocks via `@TestVisible` static variables:

```apex
@IsTest
private static void shouldUseMockedSelector() {
    // Create mock (framework-specific)
    AccountSelector mockSelector = createMock(AccountSelector.class);

    // Inject mock
    AccountSelector.instance = mockSelector;

    // Test with mocked dependency
    Test.startTest();
    AccountService.getInstance().updateAccountIndustries(accountIds);
    Test.stopTest();

    // Verify mock interactions
    verifyMockCalled(mockSelector, 'selectById', 1);
}
```

### Test Coverage Goals

- **Minimum 90% coverage** for all classes
- **100% coverage** for critical business logic
- Test **bulk scenarios** (200+ records)
- Test **error handling** paths
- Test **governor limit** scenarios
- Test **security** (user permissions, sharing)

---

## Error Handling

### UI Controllers (LWC/Aura)

**Use AuraHandledException for LWC**:

```apex
@AuraEnabled
public static List<Account> getAccounts(String industry) {
    try {
        if (String.isBlank(industry)) {
            throw new IllegalArgumentException('Industry is required');
        }

        return [
            SELECT Id, Name, Industry
            FROM Account
            WHERE Industry = :industry
            WITH USER_MODE
        ];
    } catch (Exception e) {
        throw new AuraHandledException('Error retrieving accounts: ' + e.getMessage());
    }
}
```

### Service Classes

**Return results for caller to handle**:

```apex
public class OperationResult {
    public Boolean success { get; set; }
    public String errorMessage { get; set; }
    public List<String> errors { get; set; }

    public OperationResult(Boolean success) {
        this.success = success;
        this.errors = new List<String>();
    }
}

public OperationResult processAccounts(List<Account> accounts) {
    OperationResult result = new OperationResult(true);

    try {
        List<Database.SaveResult> saveResults = Database.update(accounts, false);

        for (Integer i = 0; i < saveResults.size(); i++) {
            if (!saveResults[i].isSuccess()) {
                result.success = false;
                for (Database.Error err : saveResults[i].getErrors()) {
                    result.errors.add('Account ' + accounts[i].Name + ': ' + err.getMessage());
                }
            }
        }
    } catch (Exception e) {
        result.success = false;
        result.errorMessage = e.getMessage();
    }

    return result;
}
```

### Custom Exceptions

```apex
public class AccountValidationException extends Exception {}

public void validateAccount(Account acc) {
    if (String.isBlank(acc.Name)) {
        throw new AccountValidationException('Account Name is required');
    }
}
```

---

## Security Best Practices

### Use Security Keywords

**SOQL Security**:

```apex
// Enforce CRUD and FLS
List<Account> accounts = [
    SELECT Id, Name
    FROM Account
    WITH USER_MODE
];

// Strip inaccessible fields before DML
List<Account> accountsToInsert = getAccountsFromData();
SObjectAccessDecision decision = Security.stripInaccessible(
    AccessType.CREATABLE,
    accountsToInsert
);
insert decision.getRecords();
```

### Sharing Keywords

```apex
public with sharing class AccountService { }        // Respect user sharing
public without sharing class SystemService { }      // System context (use carefully)
public inherited sharing class FlexibleService { }  // Inherit from caller
```

### Avoid Dynamic SOQL Injection

```apex
// ✅ GOOD - Use bind variables
String accountName = 'ACME';
List<Account> accounts = [SELECT Id FROM Account WHERE Name = :accountName];

// ❌ BAD - SQL injection risk
String accountName = 'ACME';
String query = 'SELECT Id FROM Account WHERE Name = \'' + accountName + '\'';
List<Account> accounts = Database.query(query);

// ✅ GOOD - Escape user input if dynamic SOQL is necessary
String accountName = String.escapeSingleQuotes(userInput);
String query = 'SELECT Id FROM Account WHERE Name = \'' + accountName + '\'';
```

---

## Logging

### Use Logger Framework (if available)

```apex
// Preferred: Use Nebula Logger or custom logging framework
Logger.info('Processing accounts', accounts);
Logger.debug('Account count: ' + accounts.size());
Logger.warn('Low inventory detected', account);
Logger.error('Failed to update account', ex);
Logger.exception(ex); // this method logs and then throws the exception so no need to add a throw statement after this.
Logger.saveLog(); //this should only be called once in an entire transaction, preferably in the finally block in public methods only.

// Fallback: System.debug (not captured in production)
System.debug(LoggingLevel.INFO, 'Processing accounts: ' + accounts);
```

### Logging Best Practices

1. **Use appropriate log levels**:

   - `DEBUG` - Detailed diagnostic information
   - `INFO` - General informational messages
   - `WARN` - Potentially harmful situations
   - `ERROR` - Error events that might still allow the application to continue
   - `EXCEPTION` - Full exception details with stack trace

2. **Include context** in log messages:

   ```apex
   Logger.info('Processing account batch', new Map<String, Object>{
       'batchSize' => accounts.size(),
       'handlerName' => 'AccountIndustryHandler',
       'userId' => UserInfo.getUserId()
   });
   ```

3. **Don't log sensitive data** (PII, credentials, etc.)

4. **Save logs only once per transaction** in a `finally` block in public methods only:
   ```apex
   try {
       processAccounts();
   } catch (Exception ex) {
       Logger.exception(ex);
   }finally {
       Logger.saveLog();
   }
   ```

5. ***Logger.exception** method logs the exception and then throws it, so there is no need to add a throw statement after calling this method. But the code still requires a return statement from the method, unless the method's return type is void.

```apex
    public Status processAccounts() {
         try {
              // Processing logic
         } catch (Exception ex) {
              Logger.exception(ex); // Logs and throws the exception
         } finally {
              Logger.saveLog(); // Save logs at the end of the transaction
         }
        return Status.FAILED; // Return statement needed if method is not void
    }
```

---

## Async Processing

### Queueable Pattern

**Use when you need**:

- Chaining jobs
- Callouts from triggers
- Processing that exceeds synchronous limits

```apex
public class AccountProcessingQueueable implements Queueable, Database.AllowsCallouts {
  private List<Id> accountIds;
  private Integer batchSize = 200;

  public AccountProcessingQueueable(List<Id> accountIds) {
    this.accountIds = accountIds;
  }

  public void execute(QueueableContext context) {
    // Process first batch
    List<Id> currentBatch = new List<Id>();
    for (Integer i = 0; i < Math.min(batchSize, accountIds.size()); i++) {
      currentBatch.add(accountIds[i]);
    }

    // Process accounts
    List<Account> accounts = [SELECT Id, Name FROM Account WHERE Id IN :currentBatch];
    processAccounts(accounts);

    // Chain to next batch if more records remain
    List<Id> remainingIds = new List<Id>();
    for (Integer i = batchSize; i < accountIds.size(); i++) {
      remainingIds.add(accountIds[i]);
    }

    if (!remainingIds.isEmpty() && !Test.isRunningTest()) {
      System.enqueueJob(new AccountProcessingQueueable(remainingIds));
    }
  }

  private void processAccounts(List<Account> accounts) {
    // Implementation
  }
}
```

### Batch Apex Pattern

**Use when you need**:

- Processing millions of records
- Guaranteed execution
- Scheduled processing

```apex
public class AccountUpdateBatch implements Database.Batchable<SObject>, Database.Stateful {
    private Integer recordsProcessed = 0;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, Industry
            FROM Account
            WHERE LastModifiedDate < LAST_N_DAYS:30
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Account> scope) {
        List<Account> accountsToUpdate = new List<Account>();

        for (Account acc : scope) {
            acc.Industry = 'Updated';
            accountsToUpdate.add(acc);
        }

        if (!accountsToUpdate.isEmpty()) {
            List<Database.SaveResult> results = Database.update(accountsToUpdate, false);

            for (Database.SaveResult result : results) {
                if (result.isSuccess()) {
                    recordsProcessed++;
                } else {
                    // Log errors
                    Logger.error('Failed to update account', result.getErrors());
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        Logger.info('Batch completed. Records processed: ' + recordsProcessed);
        Logger.saveLog();
    }
}

// Schedule the batch
Database.executeBatch(new AccountUpdateBatch(), 200);
```

### Schedulable Pattern

```apex
public class AccountUpdateScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new AccountUpdateBatch(), 200);
    }
}

// Schedule to run daily at 2 AM
String cronExp = '0 0 2 * * ?';
System.schedule('Account Update Daily', cronExp, new AccountUpdateScheduler());
```

### Future Methods (Legacy)

**Use only when necessary** (prefer Queueable):

```apex
@future(callout=true)
public static void makeCallout(Set<Id> accountIds) {
    // Must be static
    // Cannot chain
    // Limited to primitive types
}
```

---

## Additional Resources

### Governor Limits Reference

| Resource       | Synchronous | Asynchronous      |
| -------------- | ----------- | ----------------- |
| SOQL Queries   | 100         | 200               |
| DML Statements | 150         | 150               |
| DML Rows       | 10,000      | 10,000            |
| CPU Time       | 10,000ms    | 60,000ms          |
| Heap Size      | 6 MB        | 12 MB             |
| Callouts       | 100         | 100               |
| Queueable Jobs | 50          | 1 per transaction |

### Common Patterns Summary

- **Selector**: Centralize SOQL queries
- **Service**: Business logic orchestration
- **Handler**: Single-responsibility operations
- **Trigger Handler**: Consistent trigger management
- **Queueable**: Async processing with chaining
- **Batch**: Large-scale data processing

### Key Principles

1. **Bulkify Everything**: Design for 200+ records
2. **Fail Fast**: Validate inputs early
3. **Separation of Concerns**: Use appropriate patterns
4. **Test Comprehensively**: 90%+ coverage with quality tests
5. **Security First**: Always declare sharing and use security keywords
6. **Log Appropriately**: Use logging frameworks, not System.debug
7. **Handle Errors Gracefully**: Use partial success and return results

---

## Quick Reference Checklist

Before submitting Apex code, verify:

- [ ] Sharing keyword declared (`with sharing`, `without sharing`, `inherited sharing`)
- [ ] No SOQL in loops
- [ ] No DML in loops
- [ ] Bulkified for 200+ records
- [ ] Test class with @IsTest annotation
- [ ] 90%+ test coverage
- [ ] Assertions use Assert class (not System.assertEquals)
- [ ] Error handling implemented
- [ ] Logging framework used (not System.debug)
- [ ] Security keywords used (WITH USER_MODE or WITH SYSTEM_MODE)
- [ ] JavaDoc comments for public methods
- [ ] Consistent naming conventions
- [ ] @TestVisible used for test dependencies
- [ ] Governor limits considered
