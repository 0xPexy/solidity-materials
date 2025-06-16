# Solidity DoS Attacks: Denial of Service Vulnerabilities
Denial of Service (DoS) attacks in smart contracts aim to disrupt the normal operation of a contract, preventing legitimate users from accessing its functions or resources. This document outlines two common types of DoS vulnerabilities in Solidity: Unbounded For Loops and External Call Failures.

## **1. Case 1: Unbounded For Loop (Gas Limit DoS)**

### **Description**

An **unbounded for loop** can lead to a Denial of Service (DoS) attack due to an ever-increasing gas cost associated with iterating over a growing data structure. As the size of the data (e.g., an array) within the loop increases, the computational complexity and thus the gas required to execute the function also increase. Eventually, the gas cost may exceed the block's gas limit, or the user's gas limit, making the function impossible to execute for anyone.

### **Sample Code**

Consider the following example where an array `entrants` grows with each `enter` call:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract DoS {
    address[] entrants; // Array to store addresses of entrants

    function enter() public {
        // Check for duplicate entrants by iterating through the entire array
        for (uint256 i; i < entrants.length; i++) {
            if (entrants[i] == msg.sender) {
                revert("You've already entered!"); // Revert if duplicate
            }
        }
        entrants.push(msg.sender); // Add new entrant
    }
}

```

Explanation:

In this DoS contract, the enter() function iterates through the entrants array to check for duplicates before adding a new msg.sender.

- The more users call `enter()` and the more addresses are added to the `entrants` array, the longer the `for` loop will run.
- This directly translates to higher gas consumption for each subsequent call to `enter()`.
- Eventually, the gas cost for calling `enter()` will become prohibitively expensive for users, or even exceed the maximum block gas limit, effectively preventing any further `enter()` calls. This constitutes a Denial of Service for the `enter()` function.

### **Audit Considerations (Frameworks)**

When auditing for this type of vulnerability, consider these questions:

- **Is the loop bounded to a certain size?** If an array or mapping that is iterated over has a maximum, predictable size that won't exceed gas limits, the risk is lower.
- **How much does it cost for an attacker (or even a legitimate user) to increase the size of the data structure that the loop iterates over?** If the cost to add an element is cheap (e.g., a simple `push` with low gas), but the cost to iterate over it later is high, this presents a significant attack vector.
- **If a user can cheaply increase the loop size, could this lead to a critical DoS?** If the growing data structure affects a critical function (e.g., withdrawing funds, finalizing a game), this could be a severe vulnerability.

### **Mitigation Strategies**

- **Limit Iteration:** If possible, cap the number of iterations or process items in batches.
- **Pull vs. Push:** Instead of pushing items to an array that requires iteration, use a pull mechanism where users claim their items individually.
- **Mapping for Existence Check:** For checking duplicates, use a `mapping(address => bool) public hasEntered;` instead of iterating through an array. This provides a constant-time lookup (`O(1)`), regardless of the number of entrants.

## **2. Case 2: External Call Failure (Revert DoS)**

### **Description**

External contract calls, if not handled carefully, can cause a Denial of Service by leading to unexpected reverts that propagate and block critical functionalities. This type of DoS often exploits the "fail-fast" nature of Solidity where a failed external call typically reverts the entire transaction unless explicitly caught.

### **How External Call Failures Can Cause DoS**

This vulnerability often arises when a contract iterates over a list of addresses to send Ether or tokens, and one of the recipients is a malicious or incorrectly configured contract.

1. **Sending ETH to a Contract That Cannot Accept It:**
    - If a contract tries to `call` (or `transfer`/`send`) Ether to an address that belongs to a contract without a `receive()` or `fallback()` payable function, that Ether transfer will revert.
2. **Calling a Function That Does Not Exist:**
    - If an external call targets a function that does not exist on the recipient contract, it will usually trigger the recipient's `fallback()` function. If the `fallback()` function is not implemented or not payable, or if it reverts, the entire transaction will revert.
3. **External Call Execution Runs Out of Gas:**
    - When making a low-level `call`, the caller can specify the amount of gas to forward. If the forwarded gas is insufficient for the recipient contract's logic (or if the recipient deliberately uses up all gas), the external call will fail, causing a revert.
4. **Third-Party Contract Method is Malicious:**
    - A malicious recipient contract can be programmed to always revert when called from a specific contract, or under specific conditions. If your contract relies on successfully calling such a malicious contract within a critical loop (e.g., distributing funds), the entire distribution process can be stalled indefinitely.

### **Audit Considerations (Frameworks)**

When auditing for external call failure DoS, consider these questions:

- **Is there any way for external calls to fail intentionally or unintentionally?** Identify all external calls (`call`, `delegatecall`, `staticcall`, interface calls to other contracts).
- **If an external call fails and the transaction is reverted, how can this affect the overall system?**
    - Does it block critical operations (e.g., token distribution, emergency stop)?
    - Does it lead to unfairness (e.g., some users get paid, others don't, but the state is stuck)?
    - Does it enable a griefing attack where an attacker can intentionally break the system for others at a low cost?
- **Are `try/catch` blocks used appropriately for external calls where failure is acceptable or expected?** Using `try/catch` allows a contract to gracefully handle failed external calls without reverting the entire transaction.
- **Is a "pull" payment pattern used instead of "push"?** Using a pull mechanism (where recipients actively withdraw funds) removes the risk of a single malicious recipient blocking the entire distribution.

### **Mitigation Strategies**

- **Pull Over Push:** Instead of pushing funds to multiple recipients in a loop, implement a function where each recipient can `pull` (withdraw) their allocated funds individually.
- **Handle Reverts with `try/catch`:** For non-critical external calls where a revert should not stop the entire transaction, use `try/catch` blocks to gracefully handle the failure.
- **Limit Iteration/Batching:** Similar to unbounded loops, if external calls must be made in a loop, consider limiting the number of calls per transaction or implementing a batching mechanism that can be executed incrementally.
- **Re-entrancy Guards:** While not directly a DoS, re-entrancy can be exacerbated by external calls. Ensure re-entrancy guards (e.g., `nonReentrant` modifier from OpenZeppelin) are used where funds are sent.

### **References**

- [Cyfrin's Smart Contract Exploits Minimized Repository](https://github.com/Cyfrin/sc-exploits-minimized)