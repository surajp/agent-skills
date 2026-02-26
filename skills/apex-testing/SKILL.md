---
name: apex-unit-testing
description: Use this skill when user asks to write or debug Apex tests. This skill covers best practices, tools, and examples for writing robust Apex unit tests, including test structure, governor limit management, mocking strategies, and common pitfalls.
---

# Apex Unit Testing Skills for AI Agents

This document provides essential skills, best practices, and examples for
writing robust Apex unit tests. It covers test structure, governor limit
management, mocking strategies, and common pitfalls, with a focus on
maximizing code coverage and reliability.

## Tools and Dependencies

- **UniversalMocker**: A mocking framework for Apex (see [UniversalMocker
  documentation](https://github.com/surajp/UniversalMocker))
- **Assert Class**: Built-in Salesforce assertion class (API v56.0+)
- **TestFactory Pattern**: Custom utility for creating test data (project-specific)
- **TestFactoryDefaults Pattern**: Contains inner classes that provide default values for test data creation (project-specific). Used as second argument to TestFactory.createSObject methods.

---

## Best Practices

### 1. Test Structure and Setup

- **Use @TestSetup**: Centralize test data creation in a `@TestSetup` method.
  This ensures all test methods run with consistent data and improves
  performance. Always wrap the setup logic in `Test.startTest()/Test.stopTest()`.

```apex
  @TestSetup
  private static void setupData() {
    Test.startTest();
    // Create common test records
    Account acct = new Account(Name = 'Test Account');
    insert acct;
    Test.stopTest();
  }
```

- **Keep Tests Isolated**: Each test method should verify a single behavior or scenario. Avoid dependencies between tests.

- **Use Descriptive Method Names**: Follow the convention `shouldDoSomethingWhenCondition()` for clarity.

### 2. Governor Limit Management

- **Test.startTest() / Test.stopTest()**: Wrap the main logic of each test in these calls to reset governor limits and accurately measure asynchronous behavior.

  ```apex
  Test.startTest();
  // Call method under test
  Test.stopTest();
  ```

- **Limit DML and SOQL in Tests**: Avoid unnecessary database operations to prevent hitting limits.

### 3. Using System.runAs()

- **Purpose**: Simulate different user contexts (profiles, permissions) in tests.
- **Usage**:
  ```apex
  User testUser = new User(...); // create user with desired profile
  insert testUser;
  System.runAs(testUser) {
    // Code to test under this user's context
  }
  ```
- **Recommendation**: Use only when testing logic that depends on user permissions or sharing rules. It can also be used to avoid mixed DML errors by separating setup and test execution contexts. Setup objects examples are `User`, `Group`, `Queue`, `Profile`, `PermissionSet`, `Organization`, etc.

### 4. Mocking with UniversalMocker

- **Why Mock?**: Isolate dependencies, simulate external systems, and control method outputs.
- **Setup**:
  ```apex
  UniversalMocker mocker = UniversalMocker.mock(MyService.class);
  mocker.when('getData').thenReturn(mockData);
  MyService service = (MyService)mocker.createStub();
  ```
- **Sequential Mocks**:
  ```apex
  mocker.when('getData').thenReturnUntil(2, firstResult).thenReturn(secondResult);
  ```
- **Mutating Arguments**:
  ```apex
  mocker.when('insertRecord').mutateWith(myMutatorInstance).thenReturnVoid();
  ```
- **Verification**:
  ```apex
  mocker.assertThat().method('getData').wasCalled(1);
  ```

---

### 5. Assertions: Use Assert Class

- **Why Use Assert?**: The Assert class provides more descriptive assertion methods and better error messages than the legacy System.assert methods. It supports a variety of checks (equality, null, true/false, collections, etc.) and is recommended for all new tests.
- **Common Methods**:
  - `Assert.areEqual(expected, actual, message)`
  - `Assert.isTrue(condition, message)`
  - `Assert.isFalse(condition, message)`
  - `Assert.isNull(value, message)`
  - `Assert.isNotNull(value, message)`
- **Example**:
  ```apex
  Assert.areEqual('expectedValue', actualValue, 'Should match expected value');
  Assert.isTrue(result, 'Result should be true');
  ```
- **Avoid**: Do not use `System.assert`, `System.assertEquals`, or `System.assertNotEquals` in new or updated tests.

---

## Common Pitfalls

- **Not Using @TestSetup**: Leads to redundant data creation and slower tests.
- **SOQL/DML in Loops**: Causes governor limit exceptions.
- **Missing Test.startTest()/Test.stopTest()**: Results in inaccurate limit measurement and async test failures.
- **Hardcoding IDs**: Use dynamic record creation instead.
- **Not Verifying Mock Calls**: Typos in method names or missed calls can go unnoticed.
- **Ignoring Negative Scenarios**: Always test for error handling and edge cases.

---

## Example: Well-Structured Test

```apex
@IsTest
private class MyServiceTest {
  @TestSetup
  private static void setupData() {
    // Setup common records
  }

  @IsTest
  private static void shouldReturnExpectedResultWhenValidInput() {
    UniversalMocker mocker = UniversalMocker.mock(MyDependency.class);
    mocker.when('getValue').thenReturn('mocked');
    MyDependency dep = (MyDependency) mocker.createStub();

    Test.startTest();
    String result = MyService.getInstance(dep).doSomething();
    Test.stopTest();

    Assert.areEqual('mocked', result, 'Should return mocked value');
    mocker.assertThat().method('getValue').wasCalled(1);
  }

  @IsTest
  private static void shouldRespectUserPermissions() {
    User u = TestFactory.createUserWithProfile('Standard User');
    insert u;
    System.runAs(u) {
      // Test logic under user context
    }
  }
}
```

---

## Advanced Testing Patterns

### Testing Asynchronous Apex

**Queueable Classes**:

```apex
@IsTest
private static void shouldProcessRecordsInQueueable() {
  Test.startTest();
  System.enqueueJob(new MyQueueable(recordIds));
  Test.stopTest(); // Forces queueable to complete

  // Verify results after queueable execution
  List<Account> results = [SELECT Id, Status__c FROM Account];
  Assert.areEqual('Processed', results[0].Status__c,
    'Should update status');
}
```

**Batch Classes**:

```apex
@IsTest
private static void shouldProcessRecordsInBatch() {
  Test.startTest();
  Database.executeBatch(new MyBatch(), 200);
  Test.stopTest(); // Forces batch to complete

  // Verify batch results
}
```

### Testing Triggers

- Always test triggers through their context (insert, update, delete, undelete)
- Use bulk testing with 200+ records to verify bulkification
- Mock any service dependencies injected into trigger handlers

```apex
@IsTest
private static void shouldUpdateFieldsOnAccountInsert() {
  List<Account> accounts = new List<Account>();
  for (Integer i = 0; i < 200; i++) {
    accounts.add(new Account(Name = 'Test ' + i));
  }

  Test.startTest();
  insert accounts;
  Test.stopTest();

  accounts = [SELECT Id, CustomField__c FROM Account];
  Assert.areEqual(200, accounts.size(), 'Should insert all accounts');
  Assert.isNotNull(accounts[0].CustomField__c,
    'Should populate custom field');
}
```

---

## Quick Reference

### When to Use What

- **@TestSetup**: Shared data needed across multiple test methods
- **Test.startTest/stopTest**: Every test method (wraps main test logic)
- **System.runAs()**: Testing user permissions, sharing rules, or avoiding
  mixed DML
- **UniversalMocker**: Isolating external dependencies, controlling outputs,
  verifying calls
- **Assert class**: All assertions (never use System.assert\* methods)

### Coverage Goals

- Minimum: 75% (Salesforce deployment requirement)
- Target: 90%+ with meaningful assertions
- Always test positive, negative, and bulk scenarios

---

---

## Summary of Skills

- Use `@TestSetup` for shared data (wrapped in Test.startTest/stopTest)
- Isolate each test scenario
- Always wrap main test logic in `Test.startTest()`/`Test.stopTest()`
- Use `System.runAs()` for user-context testing and mixed DML avoidance
- Mock dependencies with UniversalMocker for isolation and verification
- Assert both positive, negative, and bulk scenarios
- Avoid governor limit pitfalls (SOQL/DML in loops, excessive data)
- Use descriptive names (max 40 chars) and verify mock calls
- Test async classes by forcing execution with Test.stopTest()
- Always use Assert class methods, never System.assert\* methods
