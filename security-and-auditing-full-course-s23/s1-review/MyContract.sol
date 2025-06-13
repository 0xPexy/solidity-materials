// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract MyContract {
    uint256 public shouldAlwaysBeZero = 0;
    uint256 private hiddenValue = 0;

    function doSomething(uint256 data) public {
        // fails in fuzz testing
        if(data ==1) {
            shouldAlwaysBeZero = 1;
        }
        // fails in invariant testing
        if (hiddenValue == 8) {
            shouldAlwaysBeZero = 1;
        }
        hiddenValue = data;
    }
}
