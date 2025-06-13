# Findings

### [H-1] Storing the password on-chain makes it visible to anyone, and no longer private

**Description:** All data stored on-chain is visible to anyone and can be read directly from blockchain. The `PasswordSotre::s_password` varaible is intended to a private variable and only accessed through `PasswordStore::getPassword` function, which is intended to be only called by the owner of the contract.

We show one such method of reading any data off chain below.

**Impact:** Anyone can read the private password, severly breaking the functionality of the protocol.

**Proof of Concept(Proof of Code):** The below test case shows how anyone can read the password directly from the blockchain.

1. Create a local network
    ```bash
    make anvil
    ```

2. Deploy contract 
    ```bash
    make deploy
    ```
3. Run the storage tool
    ```bash
    cast storage <CONTRACT_ADDRESS> 1 --rpc-url localhost:8545
    ```
    You'll get output:
    ```
    0x6d7950617373776f726400000000000000000000000000000000000000000014
    ```

    You can parse it with:
    ```bash
    cast parse-bytes32-string 0x6d7950617373776f726400000000000000000000000000000000000000000014
    ```

    Result:
    ```
    myPassword
    ```
    

**Recommended Mitigation:** Due to this, the overall architecture of the contract should be rethought. One could encrypt the password on-chain. This would require the user to remember another password off-chain to decrypt the password.  

### [H-2] `PasswordStore::setPassword` has no access controls, meaning a non-owner could change the password

**Description:** The `PasswordStore::setPassword` function is set to be `external`, however, `This function allow only the owner to set the password.`
```solidity
function setPassword(string memory newPassword) external {
    // @audit - No access controls
    s_password = newPassword;
    emit SetNetPassword();
}
```

**Impact:** Anyone can change the private password, severly breaks intention of the contract.

**Proof of Concept:**
Add the following to the `test/PasswordStore.t.sol`.

```solidity
function test_anyone_can_set_password(address randomAddress) public {
    vm.assume(randomAddress != owner);
    vm.prank(randomAddress);
    string memory expectedPassword = "myNewPassword";
    passwordStore.setPassword(expectedPassword);
    vm.prank(owner);
    string memory actualPassword = passwordStore.getPassword();
    assertEq(actualPassword, expectedPassword);
}
```



**Recommended Mitigation:** Add an access control to the `setPassword` function.
```solidity
if(msg.sender!=s_onwer) {
    revert
}
```

### [I-1] The `PasswordStore::getPassword` natspec indicates a parameter doesn't exist

**Description:** 
The `PasswordStore::getPassword` signature is `getPassword()`, while the natspec says it should be `getPassword(string)`.
```solidity
/*
 * @notice This allows only the owner to retrieve the password.
 * @param newPassword The new password to set.
 */
function getPassword() external view returns (string memory) {
    if (msg.sender != s_owner) {
        revert PasswordStore__NotOwner();
    }
    return s_password;
}
```

**Impact:** The natspec is incorrect.

**Recommended Mitigation:** Remove the incorrect natspec line.

```diff
-   * @param newPassword The new password to set.
```