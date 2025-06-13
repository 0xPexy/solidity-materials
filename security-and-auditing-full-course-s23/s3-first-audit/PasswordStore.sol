// SPDX-License-Identifier: MIT
pragma solidity 0.8.18; // q: is this the correct version?

/*
 * @author not-so-secure-dev
 * @title PasswordStore
 * @notice This contract allows you to store a private password that others won't be able to see.
 * You can update your password at any time.
 */
contract PasswordStore {
    error PasswordStore__NotOwner();

    /*
     * State variables
     */
    address private s_owner;
    // @audit-high: s_password is not actually private. anyone can see the password
    string private s_password;

    /*
     * Events
     */
    event SetNetPassword();

    constructor() {
        s_owner = msg.sender;
    }

    /*
     * @notice This function allows only the owner to set a new password.
     * @param newPassword The new password to set.
     */
    // q: what's this function do? (if no comment)
    // q: can non-owner can set the password?
    // q: should a non-owner be able to set the password?
    // @audit-high: any user can set the password
    // missing-access-control
    function setPassword(string memory newPassword) external {
        s_password = newPassword;
        emit SetNetPassword();
    }

    // @audit-low: their is no newPassword parameter
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
}
