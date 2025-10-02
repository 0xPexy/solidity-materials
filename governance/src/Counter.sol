// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Counter is Ownable {
    uint256 public count = 0;

    constructor(address _owner) Ownable(_owner) {}

    function increment() external onlyOwner {
        count++;
    }
}
